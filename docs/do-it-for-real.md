# Doing it for real

Each step here runs on one machine with simulated equipment and a stand-in
router. This page is what changes on real equipment and a real goatnet. Every
row names where the procedure is; none of it was run from this repository.

| Step | Here | For real | Procedure |
|---|---|---|---|
| 1 | first-bite in a container built from a pinned commit | a release archive, or a build, installed as a systemd service | first-bite [deployment.md](https://github.com/USAREUR-AF/first-bite/blob/main/docs/deployment.md) |
| 2 | capture on a Docker bridge | a passive tap or a switch mirror port; a breakout tap gives two interfaces, `mind enp3s0 enp4s0` | first-bite [tap.md](https://github.com/USAREUR-AF/first-bite/blob/main/docs/tap.md) |
| 3 | a four-page invented document | your interface document, in a repository whose access matches the document's | first-bite [icd-to-dictionary](https://github.com/USAREUR-AF/first-bite/blob/main/docs/icd-to-dictionary/README.md), `bite new <dir> --repo` |
| 4 | a stand-in router and authority on loopback | a goatnet: the host enrolled on its mesh, an onboarding archive from its portal, the router endpoint from its administrator | first-bite [joining.md](https://github.com/USAREUR-AF/first-bite/blob/main/docs/goat/joining.md); goatcore [goatlite tutorial](https://github.com/USAREUR-AF/goatcore/blob/main/docs/tutorials/00-goatlite.md) for a goatnet of your own |
| 5 | the event printed | a subscriber on the event socket that forwards `cot_xml_string` to a TAK server | first-bite [cotify](https://github.com/USAREUR-AF/first-bite/blob/main/cotify/README.md) |

## A dictionary transcribes a document

A dictionary restates its interface document and is handled as that document
is. If the document is restricted, so are the dictionary, the tables it was
entered in, the vectors and the output of every check. Keep them where the
document may be kept, and point `--dictionary` or `BITE_DICT_PATH` at that
directory; nothing has to be copied into first-bite or into this repository.
The document in `icd/` is invented so that it can be published.

## On a goatnet, the commands of step 4 are the same

```bash
mind goat init --bundle <unpacked archive> --format <message set> --site <where> --instance <which>  --out goat.yml
mind goat check --config goat.yml --dictionary <dictionary>
mind goat probe --config goat.yml
GOAT_CONFIG_PATH=goat.yml SUBSCRIBER_CONFIG_PATH=subscribers.yml mind <interface> --dictionary <dictionary>
goat sub '<your prefix>/telemetry/**'
```

What differs is everything before them: the mesh enrolment, who mints the
certificate, and where the router is. If the probe prints `not delivered`,
send the administrator the two `put` lines of `mind goat check`.
