# Bash Base64 Encoder and Decoder

A pair of portable Bash scripts for encoding plaintext text files into Base64 and decoding Base64 files back into their original plaintext format.

The scripts support GNU/Linux and macOS, with Python 3 fallback functionality when the system's Base64 utility is unavailable.

### Features

**Encoder (`encode_base64.sh`)**
- Prompts for an input file containing plaintext entries, one per line.
- Prompts for an output file to store Base64-encoded entries.
- Supports GNU/Linux and macOS.
- Falls back to Python 3 if the Base64 utility is unavailable.
- Skips empty lines while preserving the order of non-empty entries.
- Handles Windows-style line endings (CRLF).
- Provides error handling and non-zero exit codes for fatal errors.
- Prevents accidental overwriting of existing files.

**Decoder (`decode_base64.sh`)**
- Prompts for an input file containing Base64 strings.
- Prompts for an output file for decoded plaintext.
- Detects supported Base64 decoding flags across different operating systems.
- Falls back to Python 3 when necessary.
- Skips empty lines.
- Handles invalid Base64 entries without terminating the entire process.
- Provides error handling and processing summaries.

### Usage

Make both scripts executable:

```bash
chmod +x encode_base64.sh decode_base64.sh
```

Run the encoder:

```bash
./encode_base64.sh
```

Run the decoder:

```bash
./decode_base64.sh
```

Follow the prompts to specify the input and output files.

### Important Security Note

Base64 is an encoding format, not encryption. It does not protect passwords or other sensitive information. Anyone can decode Base64-encoded content without a secret key.

**Technologies:** Bash, GNU/Linux, macOS, Python 3, Base64.