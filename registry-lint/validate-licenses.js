import { readFileSync } from "node:fs"
import yaml from "yaml"
import parse from "spdx-expression-parse"

function logBadLicense(file, badLicense) {
    console.error(
        `::error file=${file},title=Invalid license usage::Found usage of invalid SPDX license expression: "${badLicense}".`,
    );
}

const parseSpec = (filePath) => {
    const contents = readFileSync(filePath, { encoding: "utf-8" })
    return yaml.parse(contents)
}

async function main() {
    const changedPackages = process.env.PACKAGES.split(" ")

    let hasErrors = false

    for (const pkg of changedPackages) {
        const spec = parseSpec(pkg)
        for (const license of spec.licenses) {
            if (license === "proprietary") continue
            try {
                if (process.env.RUNNER_DEBUG) {
                    console.log("Parsing license", license, "for", pkg)
                }
                parse(license)
            }
            catch (e) {
                if (process.env.RUNNER_DEBUG) {
                    console.error(e)
                }
                logBadLicense(pkg, license)
                hasErrors = true
            }
        }
    }

    if (hasErrors) {
        process.exit(1)
    }
}

main().catch((x) => {
    console.error(x);
    process.exit(1);
});
