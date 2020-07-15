#!/usr/bin/env python

"""
This module provides utility functions for parsing data in the .obo (Open Biomedical Ontologies)
format and writing it out as a .tsv table for easier analysis.

The .obo format spec can be found here:
http://owlcollab.github.io/oboformat/doc/GO.format.obo-1_2.html
"""

import argparse
import collections
import contextlib
import logging
import os
import re
import sys
import urllib
import gzip

from builtins import dict
if sys.version_info >= (3, 0):
    basestring = str

logging.basicConfig(format='%(asctime)s %(levelname)-8s %(message)s')
logger = logging.getLogger(__name__)

# regex used to parse records
TAG_AND_VALUE_REGEX = "(?P<tag>[^:]+):(?P<value>[^!]+)"

# column groups and re-mappings
ONLY_ONE_ALLOWED_PER_STANZA = set(["id", "name", "def", "comment"])

def convert_obo_to_tsv(input_path, output_path=None):
    """Main entry point for parsing an .obo file and converting it to a .tsv table.

    Args:
        input_path (str): .obo file url or local file path
        output_path (str): path where to write the .tsv file. Defaults to "-" which is standard out.
    """

    # read in data
    logger.info("Parsing %s", input_path)
    with _open_input_stream(input_path) as input_stream:
        obo_records_dict = parse_obo_format(input_stream)

    # print stats and output .tsv
    print_stats(obo_records_dict, input_path)

    if output_path is None:
        write_tsv(obo_records_dict, output_stream=sys.stdout)
    else:
        with open(output_path, "w") as output_stream:
            write_tsv(obo_records_dict, output_stream)

    logger.info("Done")


def parse_obo_format(lines):
    """Parses .obo-formatted text.

    Args:
        lines (iter): Iterator over lines of text in .obo format.
    Returns:
        dict: .obo records, keyed by term id. Each record is a dictionary where the keys are tags
            such as "id", "name", "is_a", and values are strings (for tags that can only occur once
             - such as "id"), or lists (for tags that can appear multiple times per stanza - such as
             "xref")
    """

    obo_records_dict = collections.OrderedDict()
    current_stanza_type = None
    current_record = None

    for line in lines:
        if line.startswith("["):
            current_stanza_type = line.strip("[]\n")
            continue

        # skip header lines and stanzas that aren't "Terms"
        if current_stanza_type != "Term":
            continue

        # remove new-line character and any comments
        line = line.strip().split("!")[0]
        if len(line) == 0:
            continue

        match = re.match(TAG_AND_VALUE_REGEX, line)
        if not match:
            raise ValueError("Unexpected line format: %s" % str(line))

        tag = match.group("tag")
        value = match.group("value").strip().replace('"', "'")

        if tag == "id":
            current_record = collections.defaultdict(list)
            obo_records_dict[value] = current_record

        if tag in ONLY_ONE_ALLOWED_PER_STANZA:
            if tag in current_record:
                raise ValueError("More than one '%s' found in %s stanza: %s" % (
                    tag, current_stanza_type, ", ".join([current_record[tag], value])))

            current_record[tag] = value
        else:
            current_record[tag].append(value)

    return obo_records_dict


def print_stats(obo_records_dict, input_path):
    """Print various summary stats about the given .obo records.

    Args:
        obo_records_dict (dict): data structure returned by parse_obo_format(..)
        input_path (str): source path of .obo data.
    """

    if not logger.isEnabledFor(logging.INFO):
        return

    tag_counter = collections.defaultdict(int)
    value_counter = collections.defaultdict(int)
    for term_id, record in obo_records_dict.items():
        for tag, value in record.items():
            tag_counter[tag] += 1
            if isinstance(value, list):
                value_counter[tag] += len(value)

    logger.info("Parsed %s terms from %s", len(obo_records_dict), input_path)
    total_records = len(obo_records_dict)
    for tag, records_with_tag in sorted(tag_counter.items(), key=lambda t: t[1], reverse=True):
        percent_with_tag = 100*records_with_tag/float(total_records) if total_records > 0 else 0

        message = "%(records_with_tag)s out of %(total_records)s (%(percent_with_tag)0.1f%%) " \
            "records have a %(tag)s tag"
        if tag in value_counter:
            values_per_record = value_counter[tag] / float(records_with_tag)
            message += ", and have, on average, %(values_per_record)0.1f values per record."
        logger.info(message % locals())


def yield_all(obo_records_dict):
    for key, value in obo_records_dict.items():
        record = value
        yield record


def _open_input_stream(path):
    """Returns an open stream for iterating over lines in the given path.

    Args:
        path (str): url or local file path
    Return:
        iter: iterator over file handle
    """
    if not isinstance(path, basestring):
        raise ValueError("Unexpected path type: %s" % type(path))

    is_url = path.startswith("http")
    if is_url:
        line_iterator = contextlib.closing(urllib.urlopen(path))
    else:
        if not os.path.isfile(path):
            raise ValueError("File not found: %s" % path)
        if path.endswith(".gz"):
            line_iterator = gzip.open(path, 'rt')
        else:
            line_iterator = open(path)

    return line_iterator


def write_tsv(obo_records_dict, output_stream, separator=", "):
    """Write obo_records_dict to the given output_stream.

    Args:
        obo_records_dict (dict): data structure returned by parse_obo_format(..)
        output_stream (file): output stream where to write the .tsv file
        separator (str): separator for concatenating multiple values in a single column
    """

    header = ["id", "name", "is_a", "namespace", "def"]
    records = yield_all(obo_records_dict)

    for record in records:
        row = []
        for tag in header:
            value = record.get(tag)
            if value is None:
                row.append("")
            elif isinstance(value, list):
                row.append(separator.join(map(str, value)))
            else:
                row.append(str(value))
        output_stream.write("\t".join(row))
        output_stream.write("\n")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Parse an .obo file and write out a .tsv table")
    p.add_argument("-o", "--output-path", help="output .tsv file path. Defaults to standard out.")
    p.add_argument("-r", "--root-id", help="If specified, ignore ontology terms that are not "
        "either descendants of the given id or have this id themselves. For example: 'HP:0000118'.")
    p.add_argument("-a", "--return_all", action="store_true", help="Return all records instead of "
        "computing root-id [default], ignored if --root-id specified.")
    p.add_argument("input_path", help=".obo file url or local file path. For example: "
        "http://purl.obolibrary.org/obo/hp.obo")
    p.add_argument("-v", "--verbose", action="store_true", help="Print stats and other info")
    args = p.parse_args()

    if args.verbose:
        logger.setLevel(logging.INFO)
    else:
        logger.setLevel(logging.WARN)


    convert_obo_to_tsv(
        args.input_path,
        output_path=args.output_path
    )

"""
MIT License

Copyright (c) 2017 MacArthur Lab, 2020 J. Allen Baron (minor modifications)

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
"""
