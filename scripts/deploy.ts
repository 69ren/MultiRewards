import { ethers } from "hardhat";

async function main() {
  const admin: string = "";
  const stakingToken: string = "";
  const masterChef: string = "";
  const beets: string = "";
  const poolId: number = 0;
  const _name: string = "";
  const _symbol: string = "";

  const multiRewards = await ethers.deployContract("MultiRewards", [
    admin,
    stakingToken,
    masterChef,
    beets,
    poolId,
    _name,
    _symbol,
  ]);

  await multiRewards.waitForDeployment();

  console.log(await multiRewards.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
