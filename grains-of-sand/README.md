```sql
SELECT
  l.tx_hash AS log_tx_hash,
  bytearray_to_uint256(bytearray_substring (input, 133, 32)) as expires,
  bytearray_substring (input, 209, 20) as user,
  t.input
FROM
  ethereum.logs l
  LEFT JOIN ethereum.traces t ON l.tx_hash = t.tx_hash
  AND l.contract_address = t.to
WHERE
  contract_address = 0x1ce7ae555139c5ef5a57cc8d814a867ee6ee33d8
  AND topic0 = 0x3314c351c2a2a45771640a1442b843167a4da29bd543612311c031bbfb4ffa98
  AND bytearray_substring (data, 77, 20) = 0xc937f5027d47250fa2df8cbf21f6f88e98817845
  AND t.tx_success = true
  AND bytearray_starts_with (input, 0x0a19b14a)
  AND bytearray_to_uint256 (bytearray_substring (input, 133, 32)) > uint256 '18000000'
```

```
0x6ffacaa9a9c6f8e7cd7d1c6830f9bc2a146cf10c - 1257000000000
0xa219fb3cfae449f6b5157c1200652cc13e9c9ea8 - 360000000000
```