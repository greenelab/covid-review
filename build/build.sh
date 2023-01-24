#!/usr/bin/env bash

## build.sh: compile manuscript outputs from content using Manubot and Pandoc

set -o errexit \
    -o nounset \
    -o pipefail

# Set timezone used by Python for setting the manuscript's date
export TZ=Etc/UTC
# Default Python to read/write text files using UTF-8 encoding
export LC_ALL=en_US.UTF-8

# Log the external-resources commit used when building the manuscript
curl -sS https://api.github.com/repos/greenelab/covid19-review/branches/external-resources > commitinfo.json
EXTERNAL_RESOURCES_COMMIT=$(python build/read-commit.py commitinfo.json)
echo >&2 "Using external-resources commit $EXTERNAL_RESOURCES_COMMIT"

# Set DOCKER_RUNNING to true if docker is running, otherwise false.
DOCKER_RUNNING="$(docker info &> /dev/null && echo "true" || (true && echo "false"))"

# Set option defaults
CI="${CI:-false}"
BUILD_HTML="${BUILD_HTML:-true}"
BUILD_PDF="${BUILD_PDF:-true}"
BUILD_DOCX="${BUILD_DOCX:-false}"
BUILD_LATEX="${BUILD_LATEX:-false}"
SPELLCHECK="${SPELLCHECK:-false}"
MANUBOT_USE_DOCKER="${MANUBOT_USE_DOCKER:-$DOCKER_RUNNING}"
# Pandoc's configuration is specified via files of option defaults
# located in the $PANDOC_DATA_DIR/defaults directory.
PANDOC_DATA_DIR="${PANDOC_DATA_DIR:-build/pandoc}"

# Generate reference information
# Can skip this step if only building the individual manuscripts
if [ "${BUILD_HTML}" != "false" ] || [ "${BUILD_PDF}" != "false" ] || [ "${BUILD_DOCX}" = "true" ]; then
  echo >&2 "Updating contributions for merged manuscript"
  python build/update-author-metadata.py --keyword=merged --path=content/metadata.yaml

  echo >&2 "Retrieving and processing reference metadata"
  manubot process \
    --content-directory=content \
    --output-directory=output \
    --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/CORD-19/cord19-stats.json \
    --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/csse/csse-stats.json \
    --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/ebmdatalab/ebmdatalab-stats.json \
    --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/owiddata/owiddata-stats.json \
    --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/analyze-ms-stats/manuscript_stats.json \
    --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/contrib-viz/covid19-review-stats.json \
    --cache-directory=ci/cache \
    --skip-citations \
    --log-level=INFO
fi

# Make output directory
mkdir -p output

# Create HTML output
# https://pandoc.org/MANUAL.html
if [ "${BUILD_HTML}" != "false" ]; then
  echo >&2 "Exporting HTML manuscript"
  pandoc --verbose \
    --data-dir="$PANDOC_DATA_DIR" \
    --defaults=common.yaml \
    --defaults=html.yaml \
    output/manuscript.md
fi

# Create PDF output (unless BUILD_PDF environment variable equals "false")
# If Docker is not available, use WeasyPrint to create PDF
if [ "${BUILD_PDF}" != "false" ] && [ "${MANUBOT_USE_DOCKER}" != "true" ]; then
  echo >&2 "Exporting PDF manuscript using WeasyPrint"
  if [ -L images ]; then rm images; fi  # if images is a symlink, remove it
  ln -s content/images
  pandoc \
    --data-dir="$PANDOC_DATA_DIR" \
    --defaults=common.yaml \
    --defaults=html.yaml \
    --defaults=pdf-weasyprint.yaml \
    output/manuscript.md
  rm images
fi

# If Docker is available, use athenapdf to create PDF
if [ "${BUILD_PDF}" != "false" ] && [ "${MANUBOT_USE_DOCKER}" == "true" ]; then
  echo >&2 "Exporting HTML manuscript for Athena"
  pandoc --verbose \
    --data-dir="$PANDOC_DATA_DIR" \
    --defaults=common.yaml \
    --defaults=athenapdf.yaml \
    output/manuscript.md

  echo >&2 "Exporting PDF manuscript using Docker + Athena"
  if [ "${CI}" = "true" ]; then
    # Increase --delay for CI builds to ensure the webpage fully renders, even when the CI server is under high load.
    # Local builds default to a shorter --delay to minimize runtime, assuming proper rendering is less crucial.
    MANUBOT_ATHENAPDF_DELAY="${MANUBOT_ATHENAPDF_DELAY:-5000}"
    echo >&2 "Continuous integration build detected. Setting athenapdf --delay=$MANUBOT_ATHENAPDF_DELAY"
  fi
  if [ -d output/images ]; then rm -rf output/images; fi  # if images is a directory, remove it
  cp -R -L content/images output/
  docker run \
    --rm \
    --shm-size=1g \
    --volume="$(pwd)/output:/converted/" \
    --security-opt=seccomp:unconfined \
    arachnysdocker/athenapdf:2.16.0 \
    athenapdf \
    --delay=${MANUBOT_ATHENAPDF_DELAY:-1100} \
    --timeout=240 \
    --pagesize=A4 \
    manuscript-athena.html manuscript.pdf
  rm -rf output/images
  rm output/manuscript-athena.html
fi

# Create DOCX output (if BUILD_DOCX environment variable equals "true")
if [ "${BUILD_DOCX}" = "true" ]; then
  echo >&2 "Exporting Word Docx manuscript"
  pandoc --verbose \
    --data-dir="$PANDOC_DATA_DIR" \
    --defaults=common.yaml \
    --defaults=docx.yaml \
    output/manuscript.md
fi

# Create LaTeX output (if BUILD_LATEX environment variable equals "true")
if [ "${BUILD_LATEX}" = "true" ]; then
  echo >&2 "Exporting LaTeX manuscript"
  pandoc \
    --data-dir="$PANDOC_DATA_DIR" \
    --defaults=common.yaml \
    --defaults=latex.yaml
fi

# Spellcheck
if [ "${SPELLCHECK}" = "true" ]; then
  # Rebuild the manuscript after removing the appendices so they are excluded from spellcheck
  rm content/*appendix*.md
  manubot process \
    --content-directory=content \
    --output-directory=spellcheck-output \
    --cache-directory=ci/cache \
    --skip-citations \
    --log-level=CRITICAL

  export ASPELL_CONF="add-extra-dicts $(pwd)/build/assets/custom-dictionary.txt; ignore-case true; ignore 1"

  # Identify and store spelling errors
  pandoc \
    --data-dir="$PANDOC_DATA_DIR" \
    --lua-filter spellcheck.lua \
    spellcheck-output/manuscript.md \
    | sort -fu > output/spelling-errors.txt
  echo >&2 "Potential spelling errors:"
  cat output/spelling-errors.txt

  # Add additional forms of punctuation that Pandoc converts so that the
  # locations can be detected
  # Create a new expanded spelling errors file so that the saved artifact
  # contains only the original misspelled words
  cp output/spelling-errors.txt output/expanded-spelling-errors.txt
  grep "’" output/spelling-errors.txt | sed "s/’/'/g" >> output/expanded-spelling-errors.txt || true

  # Find locations of spelling errors
  # Use "|| true" after grep because otherwise this step of the pipeline will
  # return exit code 1 if any of the markdown files do not contain a
  # misspelled word
  cat output/expanded-spelling-errors.txt | while read word; do grep -ion "\<$word\>" content/*.md; done | sort -h -t ":" -k 1b,1 -k2,2 > output/spelling-error-locations.txt || true
  echo >&2 "Filenames and line numbers with potential spelling errors:"
  cat output/spelling-error-locations.txt

  rm output/expanded-spelling-errors.txt
fi

# Create litsearch output if requested via environment variable
if [ "${LITSEARCH:-}" = "true" ]; then
  echo >&2 "Creating the sources cross-reference output"
  python build/litsearch/getInternalData.py
  # Disable Allen AI cross-referencing to avoid error:
  # 'remote: error: File AllenAI-metadata.csv.gz is 102.43 MB; this exceeds GitHub's file size limit of 100.00 MB'
  #echo >&2 "Getting ALLEN AI metadata and combining it with the sources cross-reference output and additional data from bioRxiv"
  #python build/litsearch/combineDataSets.py
fi

# Could combine most of the docx and LaTex preparations into a single function
if [ "${BUILD_INDIVIDUAL:-}" = "true" ]; then
  # Build DOCX outputs for individual manuscripts
  # Builds all manuscripts listed in content/individual-docx-manuscripts.txt
  # Expect one individual manuscript keyword (e.g. pathogenesis) per line
  # Strip trailing whitespace
  for INDIVIDUAL_KEYWORD in $(cat content/individual-docx-manuscripts.txt | sed 's/[[:space:]]*$//'); do
    echo >&2 "Exporting Word Docx $INDIVIDUAL_KEYWORD manuscript"

    # Copy all content, then remove all markdown files not needed for the individual manuscript
    mkdir -p content/$INDIVIDUAL_KEYWORD
    # Ignore errors about not copying directories
    cp content/* content/$INDIVIDUAL_KEYWORD || true
    cp -r content/images/ content/$INDIVIDUAL_KEYWORD
    find content/$INDIVIDUAL_KEYWORD -type f \( -not -name "*$INDIVIDUAL_KEYWORD*" -and -not -name "*matter*" -and -not -name "*contribs*" -and -name "*.md" \) | xargs rm

    # Select the authors for the individual manuscript
    python build/update-author-metadata.py --keyword $INDIVIDUAL_KEYWORD --path content/$INDIVIDUAL_KEYWORD/metadata.yaml

    # Use the first line of the Markdown file as the manuscript title, overriding the title from metadata.yaml
    INDIVIDUAL_TITLE=$(head -n 1 content/$INDIVIDUAL_KEYWORD/*.$INDIVIDUAL_KEYWORD.md | sed 's/^#*\ //')
    INDIVIDUAL_MARKDOWN=$(find content/$INDIVIDUAL_KEYWORD/*.$INDIVIDUAL_KEYWORD.md)
    # Remove the section title from the start of the individual manuscript
    tail -n +2 $INDIVIDUAL_MARKDOWN > $INDIVIDUAL_MARKDOWN.tmp && mv $INDIVIDUAL_MARKDOWN.tmp $INDIVIDUAL_MARKDOWN

    # Set a variable indicating which individual manuscript is being processed
    # and another indicating docx export
    # These are used to modify some of of the boilerplate Markdown, like the front matter
    echo "individual: $INDIVIDUAL_KEYWORD" > content/$INDIVIDUAL_KEYWORD/$INDIVIDUAL_KEYWORD.yaml
    echo "format: docx" >> content/$INDIVIDUAL_KEYWORD/$INDIVIDUAL_KEYWORD.yaml

    echo >&2 "Retrieving and processing reference metadata for the $INDIVIDUAL_KEYWORD manuscript"
    manubot process \
      --content-directory=content/$INDIVIDUAL_KEYWORD \
      --output-directory=output/$INDIVIDUAL_KEYWORD \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/CORD-19/cord19-stats.json \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/csse/csse-stats.json \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/ebmdatalab/ebmdatalab-stats.json \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/owiddata/owiddata-stats.json \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/analyze-ms-stats/manuscript_stats.json \
    --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/contrib-viz/covid19-review-stats.json \
      --template-variables-path=content/$INDIVIDUAL_KEYWORD/$INDIVIDUAL_KEYWORD.yaml \
      --cache-directory=ci/cache \
      --skip-citations \
      --log-level=INFO

    pandoc --verbose \
      --data-dir="$PANDOC_DATA_DIR" \
      --defaults=common.yaml \
      --defaults=docx.yaml \
      --metadata=title:"$INDIVIDUAL_TITLE" \
      output/$INDIVIDUAL_KEYWORD/manuscript.md
      mv output/manuscript.docx output/$INDIVIDUAL_KEYWORD-manuscript.docx

    rm -rf content/$INDIVIDUAL_KEYWORD
    rm -rf output/$INDIVIDUAL_KEYWORD
  done


  # Build tex outputs for individual manuscripts
  # Builds all manuscripts listed in content/individual-latex-manuscripts.txt
  # Expect one individual manuscript keyword (e.g. pathogenesis) per line
  # Strip trailing whitespace
  # Outputs a tex file but does not compile a PDF
  for INDIVIDUAL_KEYWORD in $(cat content/individual-latex-manuscripts.txt | sed 's/[[:space:]]*$//'); do
    echo >&2 "Exporting LaTeX $INDIVIDUAL_KEYWORD manuscript"

    # Copy all content, then remove all markdown files not needed for the individual manuscript
    mkdir -p content/$INDIVIDUAL_KEYWORD
    # Ignore errors about not copying directories
    cp content/* content/$INDIVIDUAL_KEYWORD || true
    cp -r content/images/ content/$INDIVIDUAL_KEYWORD
    find content/$INDIVIDUAL_KEYWORD -type f \( -not -name "*$INDIVIDUAL_KEYWORD*" -and -not -name "*back-matter*" -and -name "*.md" \) | xargs rm

    # Select the authors for the individual manuscript
    python build/update-author-metadata.py --keyword $INDIVIDUAL_KEYWORD --path content/$INDIVIDUAL_KEYWORD/metadata.yaml

    # Use the first line of the Markdown file as the manuscript title, overriding the title from metadata.yaml
    INDIVIDUAL_TITLE=$(head -n 1 content/$INDIVIDUAL_KEYWORD/*.$INDIVIDUAL_KEYWORD.md | sed 's/^#*\ //')
    INDIVIDUAL_MARKDOWN=$(find content/$INDIVIDUAL_KEYWORD/*.$INDIVIDUAL_KEYWORD.md)
    # Remove the section title from the start of the individual manuscript
    tail -n +2 $INDIVIDUAL_MARKDOWN > $INDIVIDUAL_MARKDOWN.tmp && mv $INDIVIDUAL_MARKDOWN.tmp $INDIVIDUAL_MARKDOWN

    # Set a variable indicating which individual manuscript is being processed
    # and another indicating tex export
    # These are used to modify some of of the boilerplate Markdown, like the front matter
    echo "individual: $INDIVIDUAL_KEYWORD" > content/$INDIVIDUAL_KEYWORD/$INDIVIDUAL_KEYWORD.yaml
    echo "format: tex" >> content/$INDIVIDUAL_KEYWORD/$INDIVIDUAL_KEYWORD.yaml

    echo >&2 "Retrieving and processing reference metadata for the $INDIVIDUAL_KEYWORD manuscript"
    manubot process \
      --content-directory=content/$INDIVIDUAL_KEYWORD \
      --output-directory=output/$INDIVIDUAL_KEYWORD \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/CORD-19/cord19-stats.json \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/csse/csse-stats.json \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/ebmdatalab/ebmdatalab-stats.json \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/owiddata/owiddata-stats.json \
      --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/analyze-ms-stats/manuscript_stats.json \
    --template-variables-path=https://github.com/greenelab/covid19-review/raw/$EXTERNAL_RESOURCES_COMMIT/contrib-viz/covid19-review-stats.json \
      --template-variables-path=content/$INDIVIDUAL_KEYWORD/$INDIVIDUAL_KEYWORD.yaml \
      --cache-directory=ci/cache \
      --skip-citations \
      --log-level=INFO

    # Select and reformat parts of the Manubot-style author metadata for the Pandoc metadata
    python build/update-latex-metadata.py --keyword $INDIVIDUAL_KEYWORD \
      --manubot_metadata content/$INDIVIDUAL_KEYWORD/metadata.yaml \
      --pandoc_metadata content/$INDIVIDUAL_KEYWORD/pandoc-metadata.yaml

    pandoc --verbose \
      --data-dir="$PANDOC_DATA_DIR" \
      --defaults=latex.yaml \
      --metadata=title:"$INDIVIDUAL_TITLE" \
      --metadata-file=content/$INDIVIDUAL_KEYWORD/pandoc-metadata.yaml \
      output/$INDIVIDUAL_KEYWORD/manuscript.md
      mv output/manuscript.tex output/$INDIVIDUAL_KEYWORD-manuscript.tex

    # Translate the CSL JSON references Manubot output into BibTeX
    pandoc --verbose \
      --from=csljson \
      --to=bibtex \
      --output=output/$INDIVIDUAL_KEYWORD.bib \
      output/$INDIVIDUAL_KEYWORD/references.json

    # Remove note fields from the bib file
    # See https://regex101.com/r/x4wQVm/1
    cat output/$INDIVIDUAL_KEYWORD.bib | python -c "import re, sys; regex = r',\n  note = {[^}]*}'; subst = ''; print(re.sub(regex, subst, sys.stdin.read(), 0, re.MULTILINE))" > tmp.bib && mv tmp.bib output/$INDIVIDUAL_KEYWORD.bib

    rm -rf content/$INDIVIDUAL_KEYWORD
    rm -rf output/$INDIVIDUAL_KEYWORD
  done
fi

echo >&2 "Build complete"
