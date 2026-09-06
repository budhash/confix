// Type declarations for @budhash/confix. Hand-maintained (the package ships no
// build step); the public surface is two functions, pinned by the shared
// conformance suite.

export interface ConfixOptions {
  /** Separator between a key and its value in the file. Default `"="`. */
  sep?: string;
  /** Comment character marking a line as commented out. Default `"#"`. */
  comment?: string;
}

/**
 * Apply an ordered list of confix commands to `text` and return the new text.
 *
 * Each command's first character selects the operation:
 * - `key=value`  update an existing key (no-op if absent)
 * - `>key=value` set the key, appending it if absent
 * - `>key`       uncomment an existing key
 * - `<key`       comment out an existing key
 * - `!key`       delete the key's line (active or commented)
 *
 * The key/value split is on the first `=` in the command, independent of `sep`.
 */
export function apply(text: string, commands: string[], opts?: ConfixOptions): string;

/**
 * Parse a multi-line command block the way an `-e` file is read: one command
 * per line, skipping blank lines and lines whose first non-blank character is
 * the comment character. Leading blanks on kept commands are stripped.
 */
export function parseCommandBlock(block: string, comment?: string): string[];

declare const _default: {
  apply: typeof apply;
  parseCommandBlock: typeof parseCommandBlock;
};
export default _default;
