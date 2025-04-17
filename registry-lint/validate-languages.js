import fs from "node:fs/promises"
import path from "node:path"
import yaml from "yaml"

async function getAllFiles(directoryPath) {
    const files = []
    const entries = await fs.readdir(directoryPath, { withFileTypes: true });
    for (const file of entries) {
        const fullPath = path.join(directoryPath, file.name);
        if (file.isDirectory()) {
            files.push(...await getAllFiles(fullPath));
        } else {
            files.push(fullPath)
        }
    }
    return files
}

function logBadLanguage(badLanguage, suggestedLanguage) {
    console.error(
        `::error title=Invalid language usage::Found usage of language "${badLanguage}", use "${suggestedLanguage}" instead.`,
    );
}

const normalizeLang = (lang) => lang.toLowerCase().trim();

const parseSpec = async (filePath) => {
    const contents = await fs.readFile(filePath, "utf-8")
    return yaml.parse(contents.toString())
}

async function main() {
    const allPackages = await getAllFiles("packages")
    const changedPackages = process.env.PACKAGES.split(" ")
    const languagesToValidate = new Set()

    for (const pkg of changedPackages) {
        const spec = await parseSpec(pkg)
        spec.languages.forEach(lang => languagesToValidate.add(normalizeLang(lang)))
    }

    const allLanguages = []

    for (const pkg of allPackages) {
        const spec = await parseSpec(pkg)
        allLanguages.push(...spec.languages)
    }

    const languageCount = {};
    const languagesNormalized = new Map();

    for (const language of allLanguages) {
        languageCount[language] = (languageCount[language] || 0) + 1;
        if (!languagesNormalized.has(language)) {
            languagesNormalized.set(language, normalizeLang(language));
        }
    }

    // Ensures that there are no language entries that are similar, but not equal, to other language entries.
    // For example, a language entry of "rust" would error if there are other packages with "Rust" as a language entry.
    // The error message suggest usage of the alternative that is most common among all packages.
    const canonicalLanguages = new Map();
    const badLanguages = new Map();
    for (const [language, languageNormalized] of languagesNormalized.entries()) {
        if (!languagesToValidate.has(languageNormalized)) continue

        if (canonicalLanguages.has(languageNormalized)) {
            const count1 = languageCount[language];
            const count2 = languageCount[canonicalLanguages.get(languageNormalized)];

            if (count1 > count2) {
                badLanguages.set(canonicalLanguages.get(languageNormalized), language);
                canonicalLanguages.set(languageNormalized, language);
            } else {
                badLanguages.set(language, canonicalLanguages.get(languageNormalized));
            }
        } else {
            canonicalLanguages.set(languageNormalized, language);
        }
    }

    if (badLanguages.size > 0) {
        for (const [badLanguage, suggestedLanguage] of badLanguages.entries()) {
            logBadLanguage(badLanguage, suggestedLanguage);
        }
        process.exit(1);
    }
}

main().catch((x) => {
    console.error(x);
    process.exit(1);
});
