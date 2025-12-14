"""
Evaluate trained CNN-LSTM model on test set

Generates comprehensive metrics including:
- Accuracy, Precision, Recall, F1-Score
- Confusion Matrix
- ROC Curve and AUC
- Per-class metrics
"""

import os
import numpy as np
import pickle
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    confusion_matrix, classification_report, roc_auc_score, roc_curve
)
import tensorflow as tf
from tensorflow import keras

# Paths
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'processed')
MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'models', 'trained')


def load_model():
    """Load trained model"""
    model_path = os.path.join(MODEL_DIR, 'af_cnn_lstm.keras')
    return keras.models.load_model(model_path)


def evaluate_model():
    """Evaluate model with comprehensive metrics"""
    print("=" * 60)
    print("Evaluating CNN-LSTM AF Detection Model")
    print("=" * 60)
    
    # Load test data
    print("\nLoading test data...")
    X_test = np.load(os.path.join(DATA_DIR, 'X_test.npy'))
    y_test = np.load(os.path.join(DATA_DIR, 'y_test.npy'))
    print(f"Test samples: {len(X_test)}")
    print(f"AF ratio: {np.mean(y_test):.2%}")
    
    # Load model
    print("\nLoading model...")
    model = load_model()
    
    # Predict
    print("\nRunning predictions...")
    y_pred_proba = model.predict(X_test, verbose=0)
    y_pred = (y_pred_proba > 0.5).astype(int).flatten()
    
    # Calculate metrics
    print("\n" + "=" * 60)
    print("EVALUATION RESULTS")
    print("=" * 60)
    
    # Basic metrics
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred)
    recall = recall_score(y_test, y_pred)  # Sensitivity
    f1 = f1_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_pred_proba)
    
    # Specificity (recall for class 0)
    tn, fp, fn, tp = confusion_matrix(y_test, y_pred).ravel()
    specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
    
    print(f"\n{'Metric':<20} {'Value':>10}")
    print("-" * 32)
    print(f"{'Accuracy':<20} {accuracy:>10.4f}")
    print(f"{'Precision':<20} {precision:>10.4f}")
    print(f"{'Recall (Sensitivity)':<20} {recall:>10.4f}")
    print(f"{'Specificity':<20} {specificity:>10.4f}")
    print(f"{'F1-Score':<20} {f1:>10.4f}")
    print(f"{'AUC-ROC':<20} {auc:>10.4f}")
    
    # Confusion Matrix
    print("\nConfusion Matrix:")
    print("-" * 32)
    cm = confusion_matrix(y_test, y_pred)
    print(f"                Predicted")
    print(f"                Normal   AF")
    print(f"Actual Normal    {cm[0][0]:5d}  {cm[0][1]:5d}")
    print(f"Actual AF        {cm[1][0]:5d}  {cm[1][1]:5d}")
    
    # Classification Report
    print("\nClassification Report:")
    print("-" * 32)
    print(classification_report(y_test, y_pred, target_names=['Normal', 'AF']))
    
    # Save results
    results = {
        'accuracy': accuracy,
        'precision': precision,
        'recall': recall,
        'specificity': specificity,
        'f1_score': f1,
        'auc_roc': auc,
        'confusion_matrix': cm,
        'y_test': y_test,
        'y_pred': y_pred,
        'y_pred_proba': y_pred_proba
    }
    
    results_path = os.path.join(MODEL_DIR, 'evaluation_results.pkl')
    with open(results_path, 'wb') as f:
        pickle.dump(results, f)
    print(f"\n✓ Results saved: {results_path}")
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    if accuracy >= 0.90 and recall >= 0.85 and specificity >= 0.90:
        print("✓ Model meets all target thresholds!")
        print("  - Accuracy ≥ 90%: ✓")
        print("  - Sensitivity ≥ 85%: ✓") 
        print("  - Specificity ≥ 90%: ✓")
    else:
        print("⚠ Model needs improvement:")
        print(f"  - Accuracy ≥ 90%: {'✓' if accuracy >= 0.90 else '✗'}")
        print(f"  - Sensitivity ≥ 85%: {'✓' if recall >= 0.85 else '✗'}")
        print(f"  - Specificity ≥ 90%: {'✓' if specificity >= 0.90 else '✗'}")
    
    print("=" * 60)
    
    return results


if __name__ == '__main__':
    evaluate_model()
