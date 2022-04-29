const process = require('process')

const CLI = {

    run(cmd) {
        const connection = new Connection({});

        if (connection.provider.connection.url !== 'http://localhost:8545') {
            throw new Error(`check yoself b4 u wreck urself: ${connection.provider.connection.url}`)
        }

        // We recommend this pattern to be able to use async/await everywhere
        // and properly handle errors.
        try {
            return cmd(connection)
                // return cmd({/* TODO: connection? */})
                .then((args) => {
                    console.log(`CLI.run() -> finish `, args)
                })
                .catch((error) => {
                    console.error(`CLI.run() -> error`, error);
                    process.exit(1);
                });
        } catch (e) {
            console.error(`CLI.run() -> failed`, e)
        }
    },
}

export default CLI