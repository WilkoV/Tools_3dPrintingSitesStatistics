import sys

numberOfDownloads = 0

with open(sys.argv[1], 'r') as cultsFile:
    for line in cultsFile:
        strippedLine = line.strip()
        
        if 'data-counter-value' in strippedLine:
            numberOfDownloads = strippedLine.split("=")[1].replace('"', '')

        if 'data-counter-text-singular="download"' in strippedLine:
            break

print(numberOfDownloads)
