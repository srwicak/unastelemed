"""
Preprocess MIT-BIH AF Database for CNN-LSTM training

Steps:
1. Load each record
2. Extract single channel (channel 0 - usually similar to Lead II)
3. Normalize signal to [-1, 1]
4. Create 10-second windows (2500 samples @ 250Hz)
5. Label each window based on rhythm annotations
6. Save as numpy arrays for training

Labels:
- 0: Normal / Non-AF rhythm
- 1: Atrial Fibrillation (AF)
"""

import os
import numpy as np
import wfdb
from scipy import signal as scipy_signal
import pickle

# Configuration
WINDOW_SIZE_SECONDS = 10
SAMPLE_RATE = 250  # MIT-BIH AF Database sample rate
WINDOW_SIZE = WINDOW_SIZE_SECONDS * SAMPLE_RATE  # 2500 samples
OVERLAP = 0.5  # 50% overlap between windows
STEP_SIZE = int(WINDOW_SIZE * (1 - OVERLAP))  # 1250 samples

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'mitbih_af')
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'processed')

# AF-related rhythm codes in annotations
AF_RHYTHMS = {'AFIB', 'AFL'}  # Atrial Fibrillation and Flutter
NORMAL_RHYTHMS = {'N', 'J', 'SBR', 'SVTA'}  # Normal, Junctional, others


def load_record(record_name):
    """Load a single record with signal and annotations"""
    record_path = os.path.join(DATA_DIR, record_name)
    
    # Read signal
    record = wfdb.rdrecord(record_path)
    
    # Read rhythm annotations
    ann = wfdb.rdann(record_path, 'atr')
    
    return record, ann


def extract_single_channel(record, channel=0):
    """Extract single channel and normalize"""
    # Get signal from specified channel
    signal = record.p_signal[:, channel]
    
    # Remove NaN/Inf values
    signal = np.nan_to_num(signal, nan=0.0, posinf=0.0, neginf=0.0)
    
    # Normalize to [-1, 1]
    signal_max = np.max(np.abs(signal))
    if signal_max > 0:
        signal = signal / signal_max
    
    return signal


def create_rhythm_labels(ann, signal_length, fs):
    """Create per-sample rhythm labels from annotations"""
    # Initialize all samples as unknown (will filter later)
    labels = np.zeros(signal_length, dtype=np.int8)
    
    # Get rhythm annotations
    rhythm_indices = []
    rhythm_types = []
    
    for i, aux in enumerate(ann.aux_note):
        if aux and aux.strip():
            rhythm = aux.strip().replace('(', '').replace(')', '')
            rhythm_indices.append(ann.sample[i])
            rhythm_types.append(rhythm)
    
    # If no rhythm annotations, skip
    if not rhythm_indices:
        return None
    
    # Assign labels based on rhythm segments
    for i in range(len(rhythm_indices)):
        start_idx = rhythm_indices[i]
        end_idx = rhythm_indices[i + 1] if i + 1 < len(rhythm_indices) else signal_length
        rhythm = rhythm_types[i]
        
        if rhythm in AF_RHYTHMS:
            labels[start_idx:end_idx] = 1  # AF
        elif rhythm in NORMAL_RHYTHMS:
            labels[start_idx:end_idx] = 0  # Normal
        else:
            labels[start_idx:end_idx] = -1  # Unknown/Other (will be excluded)
    
    return labels


def create_windows(signal, labels, window_size=WINDOW_SIZE, step_size=STEP_SIZE):
    """Create overlapping windows from signal with labels"""
    windows = []
    window_labels = []
    
    n_windows = (len(signal) - window_size) // step_size + 1
    
    for i in range(n_windows):
        start = i * step_size
        end = start + window_size
        
        # Get window signal
        window = signal[start:end]
        
        # Get window labels (use majority voting)
        window_label_segment = labels[start:end]
        
        # Skip windows with unknown labels (-1)
        if np.any(window_label_segment == -1):
            continue
        
        # Determine label by majority (>80% AF = AF, else Normal)
        af_ratio = np.mean(window_label_segment == 1)
        if af_ratio > 0.8:
            final_label = 1  # AF
        elif af_ratio < 0.2:
            final_label = 0  # Normal
        else:
            continue  # Skip mixed windows
        
        windows.append(window)
        window_labels.append(final_label)
    
    return np.array(windows), np.array(window_labels)


def preprocess_all_records():
    """Preprocess all records and create training dataset"""
    print("=" * 60)
    print("Preprocessing MIT-BIH AF Database")
    print("=" * 60)
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    all_windows = []
    all_labels = []
    stats = {'total_records': 0, 'af_windows': 0, 'normal_windows': 0}
    
    # Get list of available records
    record_files = [f.replace('.hea', '') for f in os.listdir(DATA_DIR) if f.endswith('.hea')]
    print(f"Found {len(record_files)} records")
    
    for record_name in record_files:
        try:
            print(f"\nProcessing: {record_name}")
            
            # Load record
            record, ann = load_record(record_name)
            print(f"  Signal length: {record.sig_len} samples ({record.sig_len / record.fs / 3600:.2f} hours)")
            
            # Extract single channel
            signal = extract_single_channel(record, channel=0)
            print(f"  Extracted channel 0, normalized to [-1, 1]")
            
            # Create rhythm labels
            labels = create_rhythm_labels(ann, len(signal), record.fs)
            if labels is None:
                print(f"  ⚠ No rhythm annotations, skipping")
                continue
            
            # Create windows
            windows, window_labels = create_windows(signal, labels)
            print(f"  Created {len(windows)} windows")
            
            if len(windows) == 0:
                print(f"  ⚠ No valid windows, skipping")
                continue
            
            # Count AF vs Normal
            n_af = np.sum(window_labels == 1)
            n_normal = np.sum(window_labels == 0)
            print(f"  AF windows: {n_af}, Normal windows: {n_normal}")
            
            all_windows.append(windows)
            all_labels.append(window_labels)
            
            stats['total_records'] += 1
            stats['af_windows'] += n_af
            stats['normal_windows'] += n_normal
            
        except Exception as e:
            print(f"  ✗ Error: {str(e)}")
    
    # Combine all data
    print("\n" + "=" * 60)
    print("Combining data...")
    
    X = np.vstack(all_windows)
    y = np.concatenate(all_labels)
    
    print(f"Total windows: {len(X)}")
    print(f"  AF: {stats['af_windows']} ({100 * stats['af_windows'] / len(X):.1f}%)")
    print(f"  Normal: {stats['normal_windows']} ({100 * stats['normal_windows'] / len(X):.1f}%)")
    
    # Reshape for CNN-LSTM: (samples, timesteps, features)
    X = X.reshape(-1, WINDOW_SIZE, 1)
    
    # Split into train/val/test (80/10/10)
    from sklearn.model_selection import train_test_split
    
    X_train, X_temp, y_train, y_temp = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.5, random_state=42, stratify=y_temp
    )
    
    print(f"\nData split:")
    print(f"  Train: {len(X_train)} samples")
    print(f"  Val:   {len(X_val)} samples")
    print(f"  Test:  {len(X_test)} samples")
    
    # Save processed data
    print(f"\nSaving to {OUTPUT_DIR}...")
    
    np.save(os.path.join(OUTPUT_DIR, 'X_train.npy'), X_train)
    np.save(os.path.join(OUTPUT_DIR, 'y_train.npy'), y_train)
    np.save(os.path.join(OUTPUT_DIR, 'X_val.npy'), X_val)
    np.save(os.path.join(OUTPUT_DIR, 'y_val.npy'), y_val)
    np.save(os.path.join(OUTPUT_DIR, 'X_test.npy'), X_test)
    np.save(os.path.join(OUTPUT_DIR, 'y_test.npy'), y_test)
    
    # Save metadata
    metadata = {
        'window_size': WINDOW_SIZE,
        'sample_rate': SAMPLE_RATE,
        'overlap': OVERLAP,
        'stats': stats,
        'train_size': len(X_train),
        'val_size': len(X_val),
        'test_size': len(X_test)
    }
    
    with open(os.path.join(OUTPUT_DIR, 'metadata.pkl'), 'wb') as f:
        pickle.dump(metadata, f)
    
    print("\n✓ Preprocessing complete!")
    print("=" * 60)
    
    return X_train, y_train, X_val, y_val, X_test, y_test


if __name__ == '__main__':
    preprocess_all_records()
