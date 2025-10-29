# Site Migration

A tool for migrating website content and structure from one platform to another.

## 🚀 Quick Start

Run the migration script directly from GitHub without cloning the repository:

### Using curl:
```bash
bash <(curl -s https://raw.githubusercontent.com/Mortyo666/site-migration/main/site_migration.sh)
```

### Using wget:
```bash
bash <(wget -qO- https://raw.githubusercontent.com/Mortyo666/site-migration/main/site_migration.sh)
```

---

## Description

This project provides utilities and scripts to help automate the process of migrating websites. It handles content extraction, transformation, and deployment to a new platform while preserving the original structure and functionality.

## Features

- Automated content extraction
- Structure preservation
- Media file migration
- URL mapping and redirection
- Database migration support
- Configuration management

## Requirements

- Python 3.8 or higher
- Node.js 14.x or higher
- Git
- Access to source and destination platforms

## Installation

1. Clone the repository:
```bash
git clone https://github.com/Mortyo666/site-migration.git
cd site-migration
```

2. Install dependencies:
```bash
pip install -r requirements.txt
npm install
```

3. Configure your migration settings:
```bash
cp config.example.json config.json
```

4. Edit `config.json` with your source and destination platform credentials.

## Usage

Basic migration command:
```bash
python migrate.py --config config.json
```

For more options:
```bash
python migrate.py --help
```

## Configuration

The `config.json` file should include:

- Source platform details
- Destination platform details
- Migration options and filters
- API credentials

## Testing

Run tests with:
```bash
pytest tests/
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
