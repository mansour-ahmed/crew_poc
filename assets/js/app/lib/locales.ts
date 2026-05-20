export const LOCALES = [
  { value: "en", label: "English" },
  { value: "fi", label: "Finnish" },
  { value: "pt", label: "Portuguese" },
  { value: "es", label: "Spanish" },
] as const;

export type LocaleCode = (typeof LOCALES)[number]["value"];

export const LOCALE_LABEL: Record<string, string> = LOCALES.reduce(
  (acc, { value, label }) => ({ ...acc, [value]: label }),
  {},
);
