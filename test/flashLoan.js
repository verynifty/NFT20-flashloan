// For mainnet block number 12069925 with this command:
// npx hardhat node --fork https://mainnet.infura.io/v3/INFURA_KEY  --fork-block-number 12069925

const { assert, expect } = require("chai");

const NFT20_PAIR = "0xc2bde1a2fa26890c8e6acb10c91cc6d9c11f4a73";
const MEME_PAIR = "0x60acd58d00b2bcc9a8924fdaa54a2f7c0793b3b2";
let account = "0x4B5922ABf25858d012d12bb1184e5d3d0B6D6BE4";

// TODO Tokens you want to loan from the NFT20 pool out
const TOKENS = [5770];

const MEME_TOKENS = [1];

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

		HashMaskPair = await ethers.getContractAt("INFT20Pair", NFT20_PAIR); //nft20 pool for hashmask

		Flashloan = await ethers.getContractFactory("NFTFlashloan");
		flashloan = await Flashloan.deploy();
	});

	it("should execute flash loan", async function () {
		console.log("Prepare flashloan", await Factory.logic());

		let fl_tx = await HashMaskPair.connect(signer).flashLoan(
			TOKENS, //array of ids to loan
			[1], //array of amoutns to laon, for erc721 you can just send like this
			flashloan.address, //contract of flash loan address
			"0x"
		);
	});
});
