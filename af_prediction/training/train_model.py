"""
Train CNN-LSTM Model for AF Detection

Architecture:
- CNN layers for feature extraction from ECG morphology
- LSTM layers for temporal pattern recognition
- Trained on MIT-BIH AF Database

References:
1. "Atrial Fibrillation Detection from Holter ECG Using Hybrid CNN-LSTM" (2024)
2. "CNN-LSTM-SE Algorithm for Arrhythmia Classification" (2024)
3. Pan & Tompkins (1985) - Foundation for ECG signal processing
"""

import os
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, models, callbacks
import pickle

# Paths
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'processed')
MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'models', 'trained')

# Model Configuration
WINDOW_SIZE = 2500  # 10 seconds @ 250Hz
NUM_FEATURES = 1    # Single channel


def build_cnn_lstm_model(input_shape=(WINDOW_SIZE, NUM_FEATURES)):
    """
    Build CNN-LSTM hybrid model for AF detection
    
    Architecture Design Rationale:
    - Conv1D layers: Extract local morphological features (QRS, P-wave patterns)
    - BatchNormalization: Stabilize training, improve convergence
    - MaxPooling: Reduce dimensionality while preserving important features
    - LSTM layers: Capture temporal dependencies in RR intervals
    - Dropout: Prevent overfitting
    - Sigmoid output: Binary classification (Normal vs AF)
    
    This architecture is based on recent literature (2023-2024) on hybrid 
    CNN-LSTM models for AF detection, particularly:
    - "Atrial Fibrillation Detection from Holter ECG Using Hybrid CNN-LSTM" 
    - "Development of a Hybrid Model of CNN and LSTM for Arrhythmia Detection"
    """
    
    model = models.Sequential([
        # === CNN Feature Extraction ===
        # First Conv Block - Capture basic waveform features
        layers.Conv1D(32, kernel_size=5, activation='relu', 
                      padding='same', input_shape=input_shape),
        layers.BatchNormalization(),
        layers.MaxPooling1D(pool_size=2),
        
        # Second Conv Block - Higher-level pattern recognition
        layers.Conv1D(64, kernel_size=5, activation='relu', padding='same'),
        layers.BatchNormalization(),
        layers.MaxPooling1D(pool_size=2),
        
        # Third Conv Block - Complex feature combinations
        layers.Conv1D(128, kernel_size=3, activation='relu', padding='same'),
        layers.BatchNormalization(),
        layers.MaxPooling1D(pool_size=2),
        
        # === LSTM Temporal Analysis ===
        # First LSTM - Process sequence and keep temporal info
        layers.LSTM(64, return_sequences=True),
        
        # Second LSTM - Final temporal encoding
        layers.LSTM(32),
        
        # === Classification Head ===
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.5),
        layers.Dense(1, activation='sigmoid')  # Binary: 0=Normal, 1=AF
    ])
    
    return model


def create_class_weights(y_train):
    """Calculate class weights for imbalanced dataset"""
    n_samples = len(y_train)
    n_af = np.sum(y_train == 1)
    n_normal = np.sum(y_train == 0)
    
    # Weight inversely proportional to class frequency
    weight_af = n_samples / (2 * n_af) if n_af > 0 else 1.0
    weight_normal = n_samples / (2 * n_normal) if n_normal > 0 else 1.0
    
    return {0: weight_normal, 1: weight_af}


def train_model():
    """Train the CNN-LSTM model with Resume Support"""
    print("=" * 60)
    print("Training CNN-LSTM AF Detection Model")
    print("=" * 60)
    
    # Create model directory
    os.makedirs(MODEL_DIR, exist_ok=True)
    
    # Checkpoint paths
    checkpoint_path = os.path.join(MODEL_DIR, 'af_cnn_lstm_checkpoint.keras')
    history_path = os.path.join(MODEL_DIR, 'training_history.pkl')
    
    # Load preprocessed data
    print("\nLoading preprocessed data...")
    if not os.path.exists(os.path.join(DATA_DIR, 'X_train.npy')):
        print("Data not found! Please run preprocess.py first.")
        return None, None

    X_train = np.load(os.path.join(DATA_DIR, 'X_train.npy'))
    y_train = np.load(os.path.join(DATA_DIR, 'y_train.npy'))
    X_val = np.load(os.path.join(DATA_DIR, 'X_val.npy'))
    y_val = np.load(os.path.join(DATA_DIR, 'y_val.npy'))
    
    print(f"Training samples: {len(X_train)}")
    print(f"Validation samples: {len(X_val)}")
    
    # Determine initial epoch and load model if checkpoint exists
    initial_epoch = 0
    previous_history = {}
    
    if os.path.exists(checkpoint_path):
        print(f"\nFound existing checkpoint: {checkpoint_path}")
        try:
            print("Resuming training from checkpoint...")
            model = keras.models.load_model(checkpoint_path)
            
            # Try to recover last epoch from history file
            if os.path.exists(history_path):
                with open(history_path, 'rb') as f:
                    previous_history = pickle.load(f)
                    # Infer last epoch from history length
                    if 'loss' in previous_history:
                        initial_epoch = len(previous_history['loss'])
                        print(f"Resuming from epoch {initial_epoch + 1}")
            else:
                print("Warning: History file not found, creating new training session but keeping model weights.")
                
        except Exception as e:
            print(f"Error loading checkpoint: {e}")
            print("Starting fresh training...")
            model = build_cnn_lstm_model()
    else:
        print("\nBuilding new CNN-LSTM model...")
        model = build_cnn_lstm_model()
    
    # Compile (Re-compile is safer to ensure optimizer state matches if starting fresh)
    # If resuming, load_model usually preserves optimizer state, but we ensure metrics are set
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='binary_crossentropy',
        metrics=[
            'accuracy',
            keras.metrics.Precision(name='precision'),
            keras.metrics.Recall(name='recall'),
            keras.metrics.AUC(name='auc')
        ]
    )
    
    if initial_epoch == 0:
        print("\nModel Summary:")
        model.summary()
    
    # Calculate class weights
    class_weights = create_class_weights(y_train)
    
    # Callbacks
    callback_list = [
        # Save every epoch to allow resuming
        callbacks.ModelCheckpoint(
            checkpoint_path,
            monitor='val_auc',
            verbose=1,
            save_best_only=False, # Save every epoch (overwriting) for resume capability
            save_weights_only=False,
            mode='auto'
        ),
        # Also keep a separate file for the absolute best model
        callbacks.ModelCheckpoint(
            os.path.join(MODEL_DIR, 'af_cnn_lstm_best.keras'),
            monitor='val_auc',
            mode='max',
            save_best_only=True,
            verbose=0
        ),
        callbacks.EarlyStopping(
            monitor='val_auc',
            patience=10,
            mode='max',
            restore_best_weights=True,
            verbose=1
        ),
        callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-6,
            verbose=1
        ),
        # Custom callback to save history after every epoch
        callbacks.LambdaCallback(
            on_epoch_end=lambda epoch, logs: save_history(history_path, logs, previous_history)
        )
    ]
    
    try:
        print("\n" + "-" * 60)
        print(f"Starting/Resuming training (Epoch {initial_epoch+1}/50)...")
        print("Press Ctrl+C to stop training safely (checkpoint will be preserved)")
        print("-" * 60)
        
        history = model.fit(
            X_train, y_train,
            validation_data=(X_val, y_val),
            initial_epoch=initial_epoch,
            epochs=50,
            batch_size=32,
            class_weight=class_weights,
            callbacks=callback_list,
            verbose=1
        )
        
        # Save final model properly if finished
        final_path = os.path.join(MODEL_DIR, 'af_cnn_lstm.keras')
        model.save(final_path)
        print(f"\n✓ Training finished. Model saved: {final_path}")
        
    except KeyboardInterrupt:
        print("\n\n[Warning] Training interrupted by user!")
        print(f"Last checkpoint saved at: {checkpoint_path}")
        print("You can run this script again to RESUME from the last epoch.")
        return model, None

    # Save final config
    save_model_config(WINDOW_SIZE, NUM_FEATURES, MODEL_DIR)
    
    print("\n" + "=" * 60)
    print("Training complete!")
    print("=" * 60)
    
    return model, history

def save_history(path, logs, previous_history):
    """Helper to append and save history incrementally"""
    if not os.path.exists(path) and not previous_history:
        # First time
        current_history = {k: [v] for k, v in logs.items()}
    else:
        # Load or use existing memory
        if previous_history:
            current_history = previous_history
        elif os.path.exists(path):
            with open(path, 'rb') as f:
                current_history = pickle.load(f)
        else:
             current_history = {k: [] for k in logs.items()}

        # Append new logs
        for k, v in logs.items():
            if k not in current_history:
                current_history[k] = []
            current_history[k].append(v)
            
    # Save back to file
    with open(path, 'wb') as f:
        pickle.dump(current_history, f)
        
    # Update reference
    previous_history.update(current_history)

def save_model_config(window_size, num_features, model_dir):
    config = {
        'window_size': window_size,
        'sample_rate': 250,
        'num_features': num_features,
        'architecture': 'CNN-LSTM',
        'optimizer': 'Adam',
        'loss': 'binary_crossentropy'
    }
    with open(os.path.join(model_dir, 'model_config.pkl'), 'wb') as f:
        pickle.dump(config, f)


if __name__ == '__main__':
    train_model()
