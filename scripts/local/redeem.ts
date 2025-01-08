async function main() {}

main()
    .then(() => {
        console.log('Done');
    })
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
