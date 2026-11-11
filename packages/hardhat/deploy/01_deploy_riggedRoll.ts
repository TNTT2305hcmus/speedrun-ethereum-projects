import { artifacts, deployScript } from "../rocketh/deploy.js";

export default deployScript(
  async env => {
    const diceGame = env.get("DiceGame");
    const diceGameAddress = diceGame.address;

    // Uncomment to deploy RiggedRoll contract
    const riggedRoll = await env.deploy("RiggedRoll", {
      account: env.namedAccounts.deployer,
      artifact: artifacts.RiggedRoll,
      args: [diceGameAddress],
    });

    // Please replace the text "Your Address" with your own address.
    try {
      await env.execute(riggedRoll, {
        functionName: "transferOwnership",
        args: ["0x12029881742772872f4d0BB34d949E47561BBF0a"],
        account: env.namedAccounts.deployer,
      });
    } catch (err) {
      console.log(err);
    }

    void diceGameAddress;
    void artifacts;
  },
  { tags: ["RiggedRoll"] },
);
