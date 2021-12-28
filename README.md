# dikt-converter
Bulk dictionary converter from various formats (e.g. Lingvo/DSL, StarDict etc.) to 'dikt app' supported formats (JSON and binary DIKT)

# Usage
- Install Dart SDK
- Install Python3
- Download/clone this converter repo
- Download fork of pyglossary from https://github.com/maxim-saplin/pyglossary
- Have both converter and pyglossary folder at the same directory side by side - that is required for the converter to reach out to pyglossary and run it via command line
- Run the converter via command line passing the directory with source files, e.g 'dart bin/main.dart /Users/maxim/Documents/dictionaries' (assuming you change the current directory to /dikt_converter folder first)
- To check for command line options run the converter without specifying any params, e.g. 'dart bin/main.dart'