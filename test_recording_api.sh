#!/bin/bash

# Recording History API - Quick Test Script
# Run this script to test the recording history endpoint

BASE_URL="http://localhost:3000"

echo "=========================================="
echo "Recording History API - Quick Test"
echo "=========================================="
echo ""

# Test 1: Login as Patient1
echo "✅ Test 1: Login as Patient 1..."
RESPONSE=$(curl -s -X POST $BASE_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "pasien1@email.com", "password": "patient123"}')

TOKEN=$(echo $RESPONSE | jq -r '.data.token')

if [ "$TOKEN" != "null" ]; then
  echo "   ✓ Login successful, token: ${TOKEN:0:20}..."
else
  echo "   ✗ Login failed"
  exit 1
fi
echo ""

# Test 2: Get recordings (should succeed)
echo "✅ Test 2: Fetch own recordings (authenticated)..."
curl -s -X GET "$BASE_URL/api/recordings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '{success, recordings: [.recordings[] | {id, status, reviewed_by_doctor, has_notes, diagnosis}], meta}'
echo ""

# Test 3: Get recordings without auth (should fail with 401)
echo "✅ Test 3: Fetch recordings without auth (should fail)..."
curl -s -X GET "$BASE_URL/api/recordings" \
  -H "Content-Type: application/json" | jq '{success, error, message}'
echo ""

# Test 4: Filter by status
echo "✅ Test 4: Filter by status=completed..."
curl -s -X GET "$BASE_URL/api/recordings?status=completed" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '{success, count: (.recordings | length), recordings: [.recordings[] | {id, status}]}'
echo ""

# Test 5: Pagination
echo "✅ Test 5: Pagination (page=1, per_page=5)..."
curl -s -X GET "$BASE_URL/api/recordings?page=1&per_page=5" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '{success, meta}'
echo ""

# Test 6: Login as Doctor
echo "✅ Test 6: Login as Doctor..."
DOCTOR_RESPONSE=$(curl -s -X POST $BASE_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "dr.andi@hospital.com", "password": "doctor123"}')

DOCTOR_TOKEN=$(echo $DOCTOR_RESPONSE | jq -r '.data.token')

if [ "$DOCTOR_TOKEN" != "null" ]; then
  echo "   ✓ Doctor login successful"
else
  echo "   ✗ Doctor login failed"
fi
echo ""

# Test 7: Doctor accessing patient recordings
echo "✅ Test 7: Doctor accessing patient recordings (should succeed)..."
curl -s -X GET "$BASE_URL/api/recordings?user_id=8" \
  -H "Authorization: Bearer $DOCTOR_TOKEN" \
  -H "Content-Type: application/json" | jq '{success, recordings: [.recordings[] | {id, reviewed_by_doctor, doctor_name}]}'
echo ""

# Test 8: Patient trying to access another patient's recordings
echo "✅ Test 8: Patient1 accessing Patient2 recordings (should fail with 403)..."
curl -s -X GET "$BASE_URL/api/recordings?user_id=9" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '{success, error, message}'
echo ""

# Test 9: Login as Patient3 (not reviewed)
echo "✅ Test 9: Patient with not-reviewed recording..."
PATIENT3_RESPONSE=$(curl -s -X POST $BASE_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "pasien3@email.com", "password": "patient123"}')

PATIENT3_TOKEN=$(echo $PATIENT3_RESPONSE | jq -r '.data.token')

curl -s -X GET "$BASE_URL/api/recordings" \
  -H "Authorization: Bearer $PATIENT3_TOKEN" \
  -H "Content-Type: application/json" | jq '{success, recordings: [.recordings[] | {id, status, reviewed_by_doctor, has_notes, doctor_notes, diagnosis}]}'
echo ""

echo "=========================================="
echo "All tests completed!"
echo "=========================================="
echo ""
echo "Summary of test accounts:"
echo "- pasien1@email.com / patient123 (has reviewed recording)"
echo "- pasien2@email.com / patient123 (active recording)"
echo "- pasien3@email.com / patient123 (not reviewed)"
echo "- dr.andi@hospital.com / doctor123 (can access all)"
echo ""
