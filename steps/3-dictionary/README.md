# Step 3 — from an interface document to a dictionary

**The buoy's interface document becomes data a decoder loads, and every step
of the way is checked by a command.**

An interface control document says where each field is in words and bits. A
first-bite dictionary says the same in JSON. This step goes from
[`icd/HB-ICD-001-A.md`](../../icd/HB-ICD-001-A.md), three messages on four
pages, to `dictionaries/harbour-buoy`, using the `bite` authoring commands,
and ends by comparing what it built with the committed dictionary byte for
byte. It is first-bite's
[From an ICD to a dictionary](https://github.com/USAREUR-AF/first-bite/blob/main/docs/icd-to-dictionary/README.md)
on a document small enough to read in five minutes; that guide has the
conventions, the errata procedure and a larger worked example.

```bash
bin/hello-bite 3-dictionary
```

| What the reader types | From the document's |
|---|---|
| [`icd/tables/interfaces.csv`](../../icd/tables/interfaces.csv): the port, where the message identifier and length are, how words and bits are numbered | sections 2 and 3.1, Table 4-1 |
| [`icd/tables/messages.csv`](../../icd/tables/messages.csv): each message's name, identifier and length | Table 5-1 |
| [`icd/tables/fields.csv`](../../icd/tables/fields.csv): each field as printed, `3` and `10-0` for word 3, bits 10-0 | Tables 4-1, 5-2, 5-3, 5-4 |
| [`icd/tables/values.csv`](../../icd/tables/values.csv): the labels of Operating Mode | Table 5-2a |
| the values and bytes on the `bite vectors new` lines | appendix A |

## What you should see

```text
[2] The document's numbering, tried on two fields before any is typed (section 3.1)
    $ bite range --word-bits 16 --bit0 lsb --first-word 1 --word 3 --bits 10-0
    │ start 37
    │ stop  48
    │ width 11 bits, under "bit_order": "msb0"
    │ numbering: 16-bit words numbered from 1, sent most significant byte first; bit 0 is the least significant bit of a word
    │ word 3 (payload bytes 4-5)
    │   15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
    │    .  .  .  .  .  #  #  #  #  #  #  #  #  #  #  #

[4] Import the four tables typed from the document
    $ bite import-csv tables --into harbour-buoy
    │ wrote harbour-buoy/BUOY/messages/Position.json
    │ wrote harbour-buoy/BUOY/messages/Sea State.json
    │ wrote harbour-buoy/BUOY/messages/Status.json
    │ wrote harbour-buoy/BUOY/metadata.json
    │ 1 interface, 3 messages: 4 files written, 0 unchanged

[5] The gates, before there is a vector
    $ bite coverage --strict harbour-buoy
    │ …
    │ C010 BUOY/Position: no vector expects this message
    │ C010 BUOY/Sea State: no vector expects this message
    │ C010 BUOY/Status: no vector expects this message
    │ 3 findings failing, 0 not enforced by the flags given, 0 allowed in dictionary.json

[7] The cross-check in the other direction: build the bytes from the stated values
    $ bite vectors encode harbour-buoy --vector position
    │ payload_hex 030870661a865979edf78e9643879ff1
    │ field               bits          raw                 value
    │ message_id          [0, 8)        0x3                 3
    │ message_length      [8, 16)       0x8                 8
    │ buoy_number         [16, 20)      0x7                 7
    │ sequence_number     [20, 32)      0x66                102
    │ latitude            [32, 64)      0x1a865979          44.5012345
    │ longitude           [64, 96)      0xedf78e96          -30.2543210
    │ drift_course        [96, 105)     0x87                135
    │ drift_speed         [105, 112)    0x7                 0.35
    │ satellites_in_view  [112, 116)    0x9                 9
    │ antenna_height      [116, 128)    0xff1               -1.5
    │ These bytes were built with the dictionary. Check them against the document by hand or with a second implementation.
    │ matches the vector's payload_hex

[8] The gates again
    $ bite fmt --check harbour-buoy
    │ 8 files, 0 not canonical
    $ bite check --strict harbour-buoy
    │ 1 interfaces, 3 messages, 0 errors, 0 warnings, 3/3 vectors passed
    $ bite lint harbour-buoy
    │ 0 findings, 0 allowed in dictionary.json
    $ bite coverage --strict harbour-buoy
    │ BUOY/Position: 128 bits declared, 128 covered by 10 fields, 0 gaps, 1 vector
    │ BUOY/Sea State: 96 bits declared, 96 covered by 10 fields, 0 gaps, 1 vector
    │ BUOY/Status: 64 bits declared, 64 covered by 10 fields, 0 gaps, 1 vector
    │ 3 of 3 messages fully covered; 0 named and not defined; 0 defined and not named
    │ 30 fields: 0 without a source, 0 without a description; 0 of 26 numeric fields without a unit
    │ 0 findings failing, 0 not enforced by the flags given, 0 allowed in dictionary.json

[9] Compare with the dictionary the other steps use
    $ diff -r .run/3/harbour-buoy dictionaries/harbour-buoy
    (no difference)
```

## What each gate is for

| Command | Catches |
|---|---|
| `bite range` | a misreading of the document's word and bit numbering, before it is repeated in every field |
| `bite import-csv` | arithmetic: the reader types `3` and `10-0`, the importer computes `[37, 48)` |
| `bite fmt --check` | the same definition written two ways; a field named twice |
| `bite check --strict` | a range that cannot be decoded; two fields sharing bits; a vector that does not decode to its stated values |
| `bite lint` | a name, unit, label or description off the conventions; a message with no source |
| `bite coverage --strict` | bits no field covers; a field with no description or unit; a message no vector exercises |
| `bite vectors encode --vector` | bytes in the document that the stated values do not produce |

A vector's expected values come from the document, never from the decoder.
Here they are appendix A's, and the buoy of step 2 is a second, independent
reading of the same tables: its first Sea State and Position datagrams are
the bytes of A.2 and A.3.

`bin/hello-bite 3-dictionary --record` replaces `dictionaries/harbour-buoy`
with the result, for when the document or the tables are changed on purpose.
