# Site Migration

A tool for migrating website content and structure from one platform to another.

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
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
