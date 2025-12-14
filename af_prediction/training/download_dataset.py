"""
Download MIT-BIH Atrial Fibrillation Database from PhysioNet

Dataset: https://physionet.org/content/afdb/1.0.0/

Details:
- 25 long-term ECG recordings (10 hours each)
- Sample rate: 250 Hz
- 2 channels per recording
- Includes rhythm annotations (AFIB, AFL, N, J)

Reference:
Goldberger, A., et al. (2000). PhysioBank, PhysioToolkit, and PhysioNet.
Circulation, 101(23), e215-e220.
"""

import os
import wfdb

# MIT-BIH AF Database records
AFDB_RECORDS = [
    '04015', '04043', '04048', '04126', '04746', '04908', '04936',
    '05091', '05121', '05261', '06426', '06453', '06995', '07162',
    '07859', '07879', '07910', '08215', '08219', '08378', '08405',
    '08434', '08455'
]

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'mitbih_af')


def download_afdb():
    """Download MIT-BIH AF Database using wfdb"""
    print("=" * 60)
    print("Downloading MIT-BIH Atrial Fibrillation Database")
    print("Source: PhysioNet (https://physionet.org/content/afdb/1.0.0/)")
    print("=" * 60)
    
    # Create data directory
    os.makedirs(DATA_DIR, exist_ok=True)
    
    print(f"\nDownload location: {DATA_DIR}")
    print(f"Total records to download: {len(AFDB_RECORDS)}")
    print("-" * 60)
    
    downloaded = 0
    failed = []
    
    for record_name in AFDB_RECORDS:
        try:
            print(f"\n[{downloaded + 1}/{len(AFDB_RECORDS)}] Downloading record: {record_name}")
            
            # Download record (signal + annotations)
            wfdb.dl_database(
                'afdb',
                DATA_DIR,
                records=[record_name]
            )
            
            # Verify download
            record_path = os.path.join(DATA_DIR, record_name)
            record = wfdb.rdrecord(record_path)
            ann = wfdb.rdann(record_path, 'atr')
            
            print(f"   ✓ Signal: {record.sig_len} samples, {record.n_sig} channels")
            print(f"   ✓ Sample rate: {record.fs} Hz")
            print(f"   ✓ Duration: {record.sig_len / record.fs / 3600:.2f} hours")
            print(f"   ✓ Annotations: {len(ann.sample)} rhythm markers")
            
            downloaded += 1
            
        except Exception as e:
            print(f"   ✗ Failed: {str(e)}")
            failed.append(record_name)
    
    print("\n" + "=" * 60)
    print(f"Download complete!")
    print(f"Successfully downloaded: {downloaded}/{len(AFDB_RECORDS)} records")
    
    if failed:
        print(f"Failed records: {failed}")
    
    print("=" * 60)
    return downloaded, failed


def verify_download():
    """Verify that all records are downloaded correctly"""
    print("\nVerifying downloaded records...")
    
    available = []
    missing = []
    
    for record_name in AFDB_RECORDS:
        record_path = os.path.join(DATA_DIR, record_name)
        try:
            record = wfdb.rdrecord(record_path)
            ann = wfdb.rdann(record_path, 'atr')
            available.append({
                'name': record_name,
                'samples': record.sig_len,
                'duration_hours': record.sig_len / record.fs / 3600,
                'annotations': len(ann.sample)
            })
        except Exception:
            missing.append(record_name)
    
    print(f"\nAvailable records: {len(available)}")
    print(f"Missing records: {len(missing)}")
    
    if available:
        total_hours = sum(r['duration_hours'] for r in available)
        print(f"Total recording time: {total_hours:.1f} hours")
    
    return available, missing


if __name__ == '__main__':
    # Download dataset
    download_afdb()
    
    # Verify
    verify_download()
