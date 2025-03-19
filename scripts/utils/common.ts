export function warning(message: string) {
    console.log('');
    console.log(`\x1b[31m${message}\x1b[0m`);
    console.log('');
}
