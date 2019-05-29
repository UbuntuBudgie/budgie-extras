#!/usr/bin/python3
import subprocess


# attempts to find a given key via dconf, in the given dcpath,
# that has the given subkey and given value.
# returns None if a key cannot be found


def by_subval(dcpath, subkey, value):

    # get the specific dconf path, referring to the applet's key
    last_key = None
    for line in subprocess.check_output(
        ["dconf", "dump", dcpath]
    ).decode("utf-8").splitlines():
        line = line.strip()

        # look for a key
        if line.startswith("[{") and line.endswith("}]"):
            last_key = line[1:-1]

        # not a key, check if it's a name entry and it matches the wanted name
        else:

            # lines look like subkey=parts
            parts = line.split("=")

            # not a subkey line - skip
            if len(parts) == 0:
                continue

            # single sided, empty values?
            elif len(parts) == 1:
                parts.append('')

            # grab subkey
            lsubkey = parts[0]

            # rejoin reset of split (incase there was a = in the value)
            lvalue = '='.join(line[1:])
            if lsubkey == subkey and lvalue == value:
                break

    return last_key
