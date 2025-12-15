
import os
import tensorflow as tf
from tensorflow import keras

MODEL_DIR = 'af_prediction/models/trained'
KERAS_PATH = os.path.join(MODEL_DIR, 'af_cnn_lstm.keras')
H5_PATH = os.path.join(MODEL_DIR, 'af_cnn_lstm.h5')

def convert():
    if not os.path.exists(KERAS_PATH):
        print(f"Error: Model not found at {KERAS_PATH}")
        return

    print(f"Loading model from {KERAS_PATH}...")
    model = keras.models.load_model(KERAS_PATH)
    
    print(f"Saving model to {H5_PATH} (Legacy H5 format)...")
    # save_format='h5' forces the legacy HDF5 format which is more compatible
    model.save(H5_PATH, save_format='h5')
    
    print("Success! Upload the .h5 file to your VPS.")

if __name__ == '__main__':
    convert()
