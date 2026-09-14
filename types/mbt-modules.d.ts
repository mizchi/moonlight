// vite-plugin-moonbit resolves `mbt:<package path>` specifiers to the compiled
// MoonBit output. The entry points are imported for their side effects only, so
// an ambient declaration is all TypeScript needs.
declare module 'mbt:*';
