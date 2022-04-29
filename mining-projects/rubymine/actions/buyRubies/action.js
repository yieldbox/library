const {hexlify} = require("ethers/lib/utils");
const CLI = require('../lib/CLI');
const Sanity = require("../lib/Sanity");
const {Money} = require("../lib/Money");

module.exports =
    /**
     *
     * @param contract
     * @param wallet
     * @param provider
     * @param address
     * @param {Money} amountAsMoney
     * @param txprefs
     * @return {Promise<*>}
     */
    async function buyRubies(
        {wallet, provider, address},
        {contract},
        {
            amountAsMoney
        },
        txprefs = CLI.txPrefs()) {
        // NOTE: "amount" is actually "all"
        // because we want to stake everything we can in this phase

        const amount =
            Money.toAmount(
                Sanity.shouldBeGreaterThanOne(amountAsMoney));

        return contract.connect(wallet).buyRubies(
            address,
            amount,
            true,
            true,
            txprefs)
    }