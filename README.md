# SARS-CoV-2 and COVID-19: An Evolving Review of Diagnostics and Therapeutics

<!-- usage note: edit the H1 title above to personalize the manuscript -->

[![HTML Manuscript](https://img.shields.io/badge/manuscript-HTML-blue.svg)](https://greenelab.github.io/covid19-review/)
[![PDF Manuscript](https://img.shields.io/badge/manuscript-PDF-blue.svg)](https://greenelab.github.io/covid19-review/manuscript.pdf)
[![GitHub Actions Status](https://github.com/greenelab/covid19-review/workflows/Manubot/badge.svg)](https://github.com/greenelab/covid19-review/actions)
<!-- usage note: delete CI badges above for services not used by your manuscript -->

## Project Description

<!-- usage note: edit this section. -->

With the rapidly evolving global situation related to COVID-19, the infectious disease caused by the SARS-CoV-2 virus, there is a need to centralize scientific knowledge relevant to the development of diagnostics and therapeutics. 
This repository is an online, collaborative review paper written with [manubot](https://manubot.org/). 
We are seeking input from scientists at all levels anywhere in the world.

Our goal is to quickly and accurately summarize and synthesize the papers that are coming out in order to develop a broader picture of what's being attempted and the status of those efforts.
We hope to contextualize elements of this virus and infectious disease with respect to better understood viruses and diseases (e.g., to identify shared mechanisms). 
This repository is also a living document that aims to consolidate and integrate helpful information about diagnostics and therapeutics that is circulating in decentralized spaces (e.g., Twitter threads) into a more permanent and unified format.


## Contributions

At present, there are three ways to contribute:
1. If you know of information, especially a peer-reviewed or pre-print article, that you want to see incorporated, please [create a New Paper issue](greenelab/covid19-review/issues/new?assignees=&labels=New+Paper&template=new-paper-template.md&title=New+Paper%3A+%5BTitle%5D) to let us know about it. 
(You'll need to make a free [GitHub account](https://github.com/join?source=header-home)).
2. If you have experience reading scientific literature, you can propose additions to the text through pull requests (see below). 
Pull requests that address an open issue are particularly appreciated.
3. Let others know about this effort so that they can contribute!


The [ICMJE Guidelines](http://www.icmje.org/recommendations/browse/roles-and-responsibilities/defining-the-role-of-authors-and-contributors.html) will be followed for determining authorship.

Please note that, while reading scientific literature is a particular skill, we know that people outside of science are also invested in this topic. 
Non-scientists are welcome to contribute by opening New Paper issues to let us know about topics or papers they'd like to see addressed or included. 
We would especially like to keep track of what information related to diagnostics and therapeutics is circulating in the news so that we can evaluate this information.
Undergraduate students who are interested are encouraged to open issues and submit summaries of papers on their own or other open issues. 
Please make a note that you're a student so that we can try to give you feedback!


## Pull Requests
If you are not familiar with git and GitHub, you can use [these directions](greenelab/covid19-review/blob/master/Instructions.md) to start contributing. 
Please feel encouraged to ask questions by opening a [Request for Help issue](greenelab/covid19-review/issues/new?assignees=rando2&labels=&template=request-for-help.md&title=Help%3A+%5BAdd+topic+here%5D).
This project is a collaborative effort that will benefit from the expertise of scientists across a wide range of disciplines!

For git users, to open a pull request please:
1. Fork the repository [greenelab/covid19-review](greenelab/covid19-review)
2. Add your modifications.
If writing full paragraphs, please put one sentence per line.
3. Submit a pull request to add your changes to [greenelab/covid19-review](https://github.com/greenelab/covid19-review)
4. Submit a second pull request to add your information to the bottom of the [metadata file](content/metadata.yaml) using the format outlined [here](https://github.com/manubot/rootstock/blob/master/content/metadata.yaml)


## Manubot

<!-- usage note: do not edit this section -->

Manubot is a system for writing scholarly manuscripts via GitHub.
Manubot automates citations and references, versions manuscripts using git, and enables collaborative writing via GitHub.
An [overview manuscript](https://greenelab.github.io/meta-review/ "Open collaborative writing with Manubot") presents the benefits of collaborative writing with Manubot and its unique features.
The [rootstock repository](https://git.io/fhQH1) is a general purpose template for creating new Manubot instances, as detailed in [`SETUP.md`](SETUP.md).
See [`USAGE.md`](USAGE.md) for documentation how to write a manuscript.

Please open [an issue](https://git.io/fhQHM) for questions related to Manubot usage, bug reports, or general inquiries.


### Repository directories & files

The directories are as follows:

+ [`content`](content) contains the manuscript source, which includes markdown files as well as inputs for citations and references.
  See [`USAGE.md`](USAGE.md) for more information.
+ [`output`](output) contains the outputs (generated files) from Manubot including the resulting manuscripts.
  You should not edit these files manually, because they will get overwritten.
+ [`webpage`](webpage) is a directory meant to be rendered as a static webpage for viewing the HTML manuscript.
+ [`build`](build) contains commands and tools for building the manuscript.
+ [`ci`](ci) contains files necessary for deployment via continuous integration.


### Local execution

The easiest way to run Manubot is to use [continuous integration](#continuous-integration) to rebuild the manuscript when the content changes.
If you want to build a Manubot manuscript locally, install the [conda](https://conda.io) environment as described in [`build`](build).
Then, you can build the manuscript on POSIX systems by running the following commands from this root directory.

```sh
# Activate the manubot conda environment (assumes conda version >= 4.4)
conda activate manubot

# Build the manuscript, saving outputs to the output directory
bash build/build.sh

# At this point, the HTML & PDF outputs will have been created. The remaining
# commands are for serving the webpage to view the HTML manuscript locally.
# This is required to view local images in the HTML output.

# Configure the webpage directory
manubot webpage

# You can now open the manuscript webpage/index.html in a web browser.
# Alternatively, open a local webserver at http://localhost:8000/ with the
# following commands.
cd webpage
python -m http.server
```

Sometimes it's helpful to monitor the content directory and automatically rebuild the manuscript when a change is detected.
The following command, while running, will trigger both the `build.sh` script and `manubot webpage` command upon content changes:

```sh
bash build/autobuild.sh
```

### Continuous Integration

Whenever a pull request is opened, CI (continuous integration) will test whether the changes break the build process to generate a formatted manuscript.
The build process aims to detect common errors, such as invalid citations.
If your pull request build fails, see the CI logs for the cause of failure and revise your pull request accordingly.

When a commit to the `master` branch occurs (for example, when a pull request is merged), CI builds the manuscript and writes the results to the [`gh-pages`](https://github.com/manubot/rootstock/tree/gh-pages) and [`output`](https://github.com/manubot/rootstock/tree/output) branches.
The `gh-pages` branch uses [GitHub Pages](https://pages.github.com/) to host the following URLs:

+ **HTML manuscript** at https://greenelab.github.io/covid19-review/
+ **PDF manuscript** at https://greenelab.github.io/covid19-review/manuscript.pdf

For continuous integration configuration details, see [`.github/workflows/manubot.yaml`](.github/workflows/manubot.yaml) if using GitHub Actions or [`.travis.yml`](.travis.yml) if using Travis CI.


## License

<!--
usage note: edit this section to change the license of your manuscript or source code changes to this repository.
We encourage users to openly license their manuscripts, which is the default as specified below.
-->

[![License: CC BY 4.0](https://img.shields.io/badge/License%20All-CC%20BY%204.0-lightgrey.svg)](http://creativecommons.org/licenses/by/4.0/)
[![License: CC0 1.0](https://img.shields.io/badge/License%20Parts-CC0%201.0-lightgrey.svg)](https://creativecommons.org/publicdomain/zero/1.0/)

Except when noted otherwise, the entirety of this repository is licensed under a CC BY 4.0 License ([`LICENSE.md`](LICENSE.md)), which allows reuse with attribution.
Please attribute by linking to https://github.com/manubot/rootstock.

Since CC BY is not ideal for code and data, certain repository components are also released under the CC0 1.0 public domain dedication ([`LICENSE-CC0.md`](LICENSE-CC0.md)).
All files matched by the following glob patterns are dual licensed under CC BY 4.0 and CC0 1.0:

+ `*.sh`
+ `*.py`
+ `*.yml` / `*.yaml`
+ `*.json`
+ `*.bib`
+ `*.tsv`
+ `.gitignore`

All other files are only available under CC BY 4.0, including:

+ `*.md`
+ `*.html`
+ `*.pdf`
+ `*.docx`

Please open [an issue](https://github.com/manubot/rootstock/issues) for any question related to licensing.
