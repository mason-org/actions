function logBadLanguage(badLanguage, suggestedLanguage) {
    console.error(
        `::error title=Invalid language usage::Found usage of language "${badLanguage}", use "${suggestedLanguage}" instead.`,
    );
}

async function main() {
    process.stdin.resume();
    process.stdin.setEncoding("utf8");

    let input = "";
    process.stdin.on("data", function (chunk) {
        input += chunk;
    });
    await new Promise((resolve) => process.stdin.on("end", resolve));

    const languages = JSON.parse(input);
    const languageCount = {};
    const languagesNormalized = new Map();

    for (const language of languages) {
        const languageNormalized = language.toLowerCase().trim();
        languageCount[language] = (languageCount[language] || 0) + 1;
        if (!languagesNormalized.has(language)) {
            languagesNormalized.set(language, languageNormalized);
        }
    }

    // Ensures that there are no language entries that are similar, but not equal, to other language entries.
    // For example, a language entry of "rust" would error if there are other packages with "Rust" as a language entry.
    // The error message suggest usage of the alternative that is most common among all packages.
    const canonicalLanguages = new Map();
    const badLanguages = new Map();
    for (const [language, languageNormalized] of languagesNormalized.entries()) {
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
