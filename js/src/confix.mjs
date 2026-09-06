// ESM entry point. The core (confix.js) is authored as a UMD/CommonJS module so
// it can also be the browser global and the CJS `require` target; this shim
// re-exports its named API so `import { apply } from "@budhash/confix"` works.
import cx from "./confix.js";

export const apply = cx.apply;
export const parseCommandBlock = cx.parseCommandBlock;
export default cx;
