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
    """Train the CNN-LSTM model"""
    print("=" * 60)
    print("Training CNN-LSTM AF Detection Model")
    print("=" * 60)
    
    # Create model directory
    os.makedirs(MODEL_DIR, exist_ok=True)
    
    # Load preprocessed data
    print("\nLoading preprocessed data...")
    X_train = np.load(os.path.join(DATA_DIR, 'X_train.npy'))
    y_train = np.load(os.path.join(DATA_DIR, 'y_train.npy'))
    X_val = np.load(os.path.join(DATA_DIR, 'X_val.npy'))
    y_val = np.load(os.path.join(DATA_DIR, 'y_val.npy'))
    
    print(f"Training samples: {len(X_train)}")
    print(f"Validation samples: {len(X_val)}")
    print(f"AF ratio (train): {np.mean(y_train):.2%}")
    
    # Build model
    print("\nBuilding CNN-LSTM model...")
    model = build_cnn_lstm_model()
    
    # Compile
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
    
    print("\nModel Summary:")
    model.summary()
    
    # Calculate class weights
    class_weights = create_class_weights(y_train)
    print(f"\nClass weights: {class_weights}")
    
    # Callbacks
    callback_list = [
        callbacks.EarlyStopping(
            monitor='val_auc',
            patience=10,
            mode='max',
            restore_best_weights=True,
            verbose=1
        ),
        callbacks.ModelCheckpoint(
            os.path.join(MODEL_DIR, 'af_cnn_lstm_best.keras'),
            monitor='val_auc',
            mode='max',
            save_best_only=True,
            verbose=1
        ),
        callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-6,
            verbose=1
        ),
        callbacks.TensorBoard(
            log_dir=os.path.join(MODEL_DIR, 'logs'),
            histogram_freq=1
        )
    ]
    
    # Train
    print("\n" + "-" * 60)
    print("Starting training...")
    print("-" * 60)
    
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=50,
        batch_size=32,
        class_weight=class_weights,
        callbacks=callback_list,
        verbose=1
    )
    
    # Save final model
    model_path = os.path.join(MODEL_DIR, 'af_cnn_lstm.keras')
    model.save(model_path)
    print(f"\n✓ Model saved: {model_path}")
    
    # Save training history
    history_path = os.path.join(MODEL_DIR, 'training_history.pkl')
    with open(history_path, 'wb') as f:
        pickle.dump(history.history, f)
    print(f"✓ Training history saved: {history_path}")
    
    # Save model config for documentation
    config = {
        'window_size': WINDOW_SIZE,
        'sample_rate': 250,
        'num_features': NUM_FEATURES,
        'architecture': 'CNN-LSTM',
        'input_shape': (WINDOW_SIZE, NUM_FEATURES),
        'cnn_layers': [32, 64, 128],
        'lstm_layers': [64, 32],
        'dropout': 0.5,
        'optimizer': 'Adam',
        'learning_rate': 0.001,
        'loss': 'binary_crossentropy'
    }
    
    config_path = os.path.join(MODEL_DIR, 'model_config.pkl')
    with open(config_path, 'wb') as f:
        pickle.dump(config, f)
    print(f"✓ Model config saved: {config_path}")
    
    print("\n" + "=" * 60)
    print("Training complete!")
    print("=" * 60)
    
    return model, history


if __name__ == '__main__':
    train_model()
