require("@nomiclabs/hardhat-web3");
const moment = require("moment");
const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const ANY_ADDRESS = "0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa";
const ANY_FUNC_SIGNATURE = "0xaaaaaaaa";

task("deploy-dxvote-develop", "Deploy dxvote with develop config").setAction(
  async () => {
    const PermissionRegistry = await hre.artifacts.require(
      "PermissionRegistry"
    );

    const deployconfig = {
      reputation: [
        {
          address: "0x428a2C4B6D690064850D0B9555756E79375e7191",
          amount: 6000,
        },
        {
          address: "0xF0E81381d3515874C0d03190eae7e190e8a658f2",
          amount: 4000,
        },
        {
          address: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
          amount: 1000,
        },
        {
          address: "0x22ff0428359eab1644bf905dad2733e7bf041e54",
          amount: 1000,
        },
      ],


      tokens: [
        {
          name: "EXD Testnet Token",
          symbol: "EXDT",
          type: "ERC20",
          distribution: [
            {
              address: "0x428a2C4B6D690064850D0B9555756E79375e7191",
              amount: web3.utils.toWei("5000"),
            },
            {
              address: "0x22ff0428359eab1644bf905dad2733e7bf041e54",
              amount: web3.utils.toWei("1000"),
            },
            {
              address: "0xF0E81381d3515874C0d03190eae7e190e8a658f2",
              amount: web3.utils.toWei("100"),
            },
            {
              address: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
              amount: web3.utils.toWei("100"),
            },
          ],
        },        
      ],

      permissionRegistryDelay: moment.duration(10, "seconds").asSeconds(),

      contributionReward: {
        queuedVoteRequiredPercentage: 50,
        queuedVotePeriodLimit: moment.duration(10, "minutes").asSeconds(),
        boostedVotePeriodLimit: moment.duration(3, "minutes").asSeconds(),
        preBoostedVotePeriodLimit: moment.duration(1, "minutes").asSeconds(),
        thresholdConst: 2000,
        quietEndingPeriod: moment.duration(0.5, "minutes").asSeconds(),
        proposingRepReward: 10,
        votersReputationLossRatio: 100,
        minimumDaoBounty: web3.utils.toWei("1"),
        daoBountyConst: 100,
      },

      walletSchemes: [
        {
          name: "RegistrarWalletScheme",
          doAvatarGenericCalls: true,
          maxSecondsForExecution: moment.duration(31, "days").asSeconds(),
          maxRepPercentageChange: 0,
          controllerPermissions: {
            canGenericCall: true,
            canUpgrade: true,
            canRegisterSchemes: true,
          },
          permissions: [],
          queuedVoteRequiredPercentage: 75,
          boostedVoteRequiredPercentage: 5 * 100,
          queuedVotePeriodLimit: moment.duration(15, "minutes").asSeconds(),
          boostedVotePeriodLimit: moment.duration(5, "minutes").asSeconds(),
          preBoostedVotePeriodLimit: moment.duration(2, "minutes").asSeconds(),
          thresholdConst: 2000,
          quietEndingPeriod: moment.duration(1, "minutes").asSeconds(),
          proposingRepReward: 0,
          votersReputationLossRatio: 100,
          minimumDaoBounty: web3.utils.toWei("10"),
          daoBountyConst: 100,
        },
        {
          name: "MasterWalletScheme",
          doAvatarGenericCalls: true,
          maxSecondsForExecution: moment.duration(31, "days").asSeconds(),
          maxRepPercentageChange: 40,
          controllerPermissions: {
            canGenericCall: true,
            canUpgrade: false,
            canChangeConstraints: false,
            canRegisterSchemes: false,
          },
          permissions: [
            {
              asset: "0x0000000000000000000000000000000000000000",
              to: "DXDVotingMachine",
              functionSignature: "0xaaaaaaaa",
              value:
                "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
              allowed: true,
            },
            {
              asset: "0x0000000000000000000000000000000000000000",
              to: "RegistrarWalletScheme",
              functionSignature: "0xaaaaaaaa",
              value:
                "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
              allowed: true,
            },
            {
              asset: "0x0000000000000000000000000000000000000000",
              to: "ITSELF",
              functionSignature: "0xaaaaaaaa",
              value:
                "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
              allowed: true,
            },
          ],
          queuedVoteRequiredPercentage: 50,
          boostedVoteRequiredPercentage: 2 * 100,
          queuedVotePeriodLimit: moment.duration(10, "minutes").asSeconds(),
          boostedVotePeriodLimit: moment.duration(3, "minutes").asSeconds(),
          preBoostedVotePeriodLimit: moment.duration(1, "minutes").asSeconds(),
          thresholdConst: 1500,
          quietEndingPeriod: moment.duration(0.5, "minutes").asSeconds(),
          proposingRepReward: 0,
          votersReputationLossRatio: 5,
          minimumDaoBounty: web3.utils.toWei("1"),
          daoBountyConst: 10,
        },
        {
          name: "QuickWalletScheme",
          doAvatarGenericCalls: false,
          maxSecondsForExecution: moment.duration(31, "days").asSeconds(),
          maxRepPercentageChange: 1,
          controllerPermissions: {
            canGenericCall: false,
            canUpgrade: false,
            canChangeConstraints: false,
            canRegisterSchemes: false,
          },
          permissions: [
            {
              asset: "0x0000000000000000000000000000000000000000",
              to: "0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa",
              functionSignature: "0xaaaaaaaa",
              value:
                "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
              allowed: true,
            },
            {
              asset: "EXDT",
              to: "0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa",
              functionSignature: "0xaaaaaaaa",
              value:
                "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
              allowed: true,
            },
          ],
          queuedVoteRequiredPercentage: 50,
          boostedVoteRequiredPercentage: 10 * 100,
          queuedVotePeriodLimit: moment.duration(5, "minutes").asSeconds(),
          boostedVotePeriodLimit: moment.duration(1, "minutes").asSeconds(),
          preBoostedVotePeriodLimit: moment
            .duration(0.5, "minutes")
            .asSeconds(),
          thresholdConst: 1300,
          quietEndingPeriod: moment.duration(0.5, "minutes").asSeconds(),
          proposingRepReward: 0,
          votersReputationLossRatio: 10,
          minimumDaoBounty: web3.utils.toWei("0.1"),
          daoBountyConst: 10,
        },
      ],


      startTimestampForActions: moment().subtract(10, "minutes").unix(),

      actions: [
        {
          type: "transfer",
          from: "0x22Ff0428359EAB1644bf905DaD2733e7BF041E54",
          data: {
            asset: NULL_ADDRESS,
            address: "Avatar",
            amount: web3.utils.toWei("1"),
          },
        },
        {
          type: "transfer",
          from: "0x22Ff0428359EAB1644bf905DaD2733e7BF041E54",
          data: {
            asset: "EXDT",
            address: "Avatar",
            amount: web3.utils.toWei("20"),
          },
        },

        {
          type: "proposal",
          from: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
          data: {
            to: ["PermissionRegistry"],
            callData: [
              new web3.eth.Contract(PermissionRegistry.abi).methods
                .setPermission(
                  NULL_ADDRESS,
                  "0xE0FC07f3aC4F6AF1463De20eb60Cf1A764E259db",
                  "0x1A0370A6f5b6cE96B1386B208a8519552eb714D9",
                  ANY_FUNC_SIGNATURE,
                  web3.utils.toWei("10"),
                  true
                )
                .encodeABI(),
            ],
            value: ["0"],
            title: "Proposal Test #0",
            description: "Allow sending up to 10 ETH to QuickWalletScheme",
            tags: ["dxvote"],
            scheme: "MasterWalletScheme",
          },
        },
        {
          type: "stake",
          from: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
          data: {
            proposal: "0",
            decision: "1",
            amount: web3.utils.toWei("1.01"),
          },
        },
        {
          type: "vote",
          time: moment.duration(1, "minutes").asSeconds(),
          from: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
          data: {
            proposal: "0",
            decision: "1",
            amount: "0",
          },
        },
        {
          type: "execute",
          time: moment.duration(3, "minutes").asSeconds(),
          from: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
          data: {
            proposal: "0",
          },
        },
        // {
        //   type: "redeem",
        //   from: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
        //   data: {
        //     proposal: "0",
        //   },
        // },

        {
          type: "proposal",
          from: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
          data: {
            to: ["0xdE0A2DFE54721526Aa05BE76F825Ef94CD8F585a"],
            callData: ["0x0"],
            value: [web3.utils.toWei("0.01")],
            title: "Proposal Test #1",
            description: "Send 0.01 ETH to QuickWalletScheme",
            tags: ["dxvote"],
            scheme: "MasterWalletScheme",
          },
        },
        // {
        //   type: "stake",
        //   from: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
        //   data: {
        //     proposal: "1",
        //     decision: "1",
        //     amount: web3.utils.toWei("1.01"),
        //   },
        // },
        // {
        //   type: "vote",
        //   time: moment.duration(1, "minutes").asSeconds(),
        //   from: "0xDF775EdC85fACa1B11eB97FBDeCfB89deAd8C66c",
        //   data: {
        //     proposal: "1",
        //     decision: "1",
        //     amount: "0",
        //   },
        // },
        // {
        //   type: "vote",
        //   from: "0xF0E81381d3515874C0d03190eae7e190e8a658f2",
        //   data: {
        //     proposal: "1",
        //     decision: "2",
        //     amount: "0",
        //   },
        // },

      ],
    };

    await hre.run("deploy-dxvote", {
      deployconfig: JSON.stringify(deployconfig),
    });
  }
);
