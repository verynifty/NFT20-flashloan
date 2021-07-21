// For mainnet block number 12069925 with this command:
// npx hardhat node --fork https://mainnet.infura.io/v3/INFURA_KEY  --fork-block-number 12069925

const { assert, expect } = require("chai");

const NFT20_PAIR = "0xc2bde1a2fa26890c8e6acb10c91cc6d9c11f4a73";
let account = "0x4B5922ABf25858d012d12bb1184e5d3d0B6D6BE4"; //here can be your account to impersonate

const hre = require("hardhat");

describe("Contracts", () => {
	before(async () => {
		await hre.network.provider.request({
			method: "hardhat_impersonateAccount",
			params: [account],
		});

		signer = await ethers.provider.getSigner(account);

		hashMasks = await ethers.getContractAt(
			"ERC721",
			"0xC2C747E0F7004F9E8817Db2ca4997657a7746928"
		);

		Factory = await ethers.getContractAt(
			"NFT20FactoryV4",
			"0x0f4676178b5c53Ae0a655f1B19A96387E4b8B5f2"
		);

		HashMaskPair = await ethers.getContractAt("NFT20Pair", NFT20_PAIR); //nft20 pool for hashmask

		Flashloan = await ethers.getContractFactory("NFTFlashloan");
		flashloan = await Flashloan.deploy();

		console.log("deployed flashloan contract ", flashloan.address);
	});

	it("should execute flash loan", async function () {
		console.log("executing flashloan");

		// TODO Tokens you want to loan from the NFT20 pool out
		const TOKENS = [6841];

		const amounts = [1, 2, 3];

		let fl_tx = await HashMaskPair.connect(signer).flashLoan(
			TOKENS, //array of ids to loan
			amounts, //array of amoutns to laon, for erc721 you can just send like this
			flashloan.address, //contract of flash loan address
			"0x"
		);
	});
});
