// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SigUtils } from "./SigUtils.sol";
import { Directory } from "../contracts/Directory.sol";
import { VotingContract } from "../contracts/VotingContract.sol";

contract MockSNT is ERC20 {
    constructor() ERC20("Mock SNT", "MSNT") {
        _mint(msg.sender, 1_000_000_000_000_000_000);
    }
}

contract VotingContractTest is Test {
    uint256 internal votingLength = 1000;
    uint256 internal votingVerificationLength = 200;
    uint256 internal timeBetweenVoting = 3600;
    uint256 internal votingWithVerificationLength = votingLength + votingVerificationLength;

    VotingContract internal votingContract;
    Directory internal directoryContract;
    MockSNT internal mockSNT;
    SigUtils internal sigUtils;

    address internal bob;
    uint256 internal bobsKey;
    address internal alice;
    uint256 internal alicesKey;

    bytes internal communityID1 = bytes("0x0d9cb350e1dc415303e2816a21b0a439530725b4b2b42d2948e967cb211eab89d5");
    bytes internal communityID2 = bytes("0xe84e64498172551d998a220e1d8e5893c818ee9aa90bdb855aec0c9e65e89014b8");

    event VoteCast(uint256 roomId, address voter);
    event VotingRoomStarted(uint256 roomId, bytes publicKey);
    event VotingRoomFinalized(uint256 roomId, bytes publicKey, bool passed, VotingContract.VoteType voteType);
    event NotEnoughToken(uint256 roomId, address voter);
    event InvalidSignature(uint256 roomId, address voter);
    event AlreadyVoted(uint256 roomId, address voter);

    // solhint-disable-next-line var-name-mixedcase
    bytes32 internal DOMAIN_SEPARATOR;
    // solhint-disable-next-line var-name-mixedcase
    bytes32 internal constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    // solhint-disable-next-line var-name-mixedcase
    bytes32 internal constant VOTE_TYPEHASH =
        keccak256("Vote(uint256 roomIdAndType,uint256 sntAmount,address voter,uint256 timestamp)");

    function _hashVoteData(
        uint256 roomId,
        uint256 amount,
        address voter,
        uint256 timestamp
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(VOTE_TYPEHASH, roomId, amount, voter, timestamp));
    }

    function _hashDomainData(uint256 chainId, address verifyingContract) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes("Voting Contract")),
                keccak256(bytes("1")),
                chainId,
                verifyingContract
            )
        );
    }

    function _createSignedVote(
        uint256 signer,
        address voter,
        uint256 roomId,
        VotingContract.VoteType _type,
        uint256 amount,
        uint256 timestamp
    )
        internal
        view
        returns (VotingContract.SignedVote memory)
    {
        uint256 roomIdAndType = (roomId * 2) + uint8(_type);

        bytes32 voteHash = sigUtils.getTypedDataHash(
            SigUtils.Vote({ voter: voter, sntAmount: amount, voteType: SigUtils.VoteType(uint8(_type)) }),
            roomIdAndType,
            timestamp
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, voteHash);

        return VotingContract.SignedVote({
            voter: voter,
            roomIdAndType: roomIdAndType,
            sntAmount: amount,
            timestamp: timestamp,
            r: r,
            vs: (bytes32(uint256(v > 27 ? 1 : 0)) << 255) | s
        });
    }

    function setUp() public virtual {
        mockSNT = new MockSNT();
        address featuredVotingContract = makeAddr("featuredVotingContract");
        votingContract = new VotingContract(mockSNT, votingLength, votingVerificationLength, timeBetweenVoting);
        directoryContract = new Directory(address(votingContract), featuredVotingContract);
        votingContract.setDirectory(directoryContract);

        DOMAIN_SEPARATOR = _hashDomainData(block.chainid, address(votingContract));
        sigUtils = new SigUtils(DOMAIN_SEPARATOR);

        (address bob_, uint256 bobsKey_) = makeAddrAndKey("bob");
        (address alice_, uint256 alicesKey_) = makeAddrAndKey("alice");
        bob = bob_;
        bobsKey = bobsKey_;
        alice = alice_;
        alicesKey = alicesKey_;

        mockSNT.transfer(bob, 10_000);
    }
}

contract SetDirectoryTest is VotingContractTest {
    function setUp() public virtual override {
        VotingContractTest.setUp();
    }

    function test_RevertWhen_SenderIsNotOwner() public {
        vm.expectRevert(bytes("Not owner"));
        vm.prank(bob);
        votingContract.setDirectory(directoryContract);
    }
}

contract GetActiveVotingRoomTest is VotingContractTest {
    function setUp() public virtual override {
        VotingContractTest.setUp();
    }

    function test_GetActiveVotingRoom() public {
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        VotingContract.VotingRoom memory votingRoom = votingContract.getActiveVotingRoom(communityID1);
        assertEq(votingRoom.community, communityID1);
        assertEq(votingRoom.roomNumber, 1);
        assertEq(uint256(votingRoom.voteType), 1);
        assertEq(votingRoom.finalized, false);
        assertEq(votingRoom.totalVotesFor, 100);
        assertEq(votingRoom.totalVotesAgainst, 0);
    }
}

contract GetActiveVotingRoomsTest is VotingContractTest {
    function setUp() public virtual override {
        VotingContractTest.setUp();
    }

    function test_GetActiveVotingRooms() public {
        uint256[] memory votingRooms = votingContract.getActiveVotingRooms();
        assertEq(votingRooms.length, 0);

        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        votingRooms = votingContract.getActiveVotingRooms();
        assertEq(votingRooms.length, 1);
        assertEq(votingRooms[0], 1);
    }
}

contract ListRoomVotersTest is VotingContractTest {
    function setUp() public virtual override {
        VotingContractTest.setUp();
    }

    function test_ListRoomVoters() public {
        vm.prank(bob);
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        address[] memory roomVoters = votingContract.listRoomVoters(1);
        // bob is the initial voter
        assertEq(roomVoters.length, 1);
        assertEq(roomVoters[0], bob);

        VotingContract.SignedVote[] memory votes = new VotingContract.SignedVote[](2);

        // get bob's and alice's votes
        votes[0] = _createSignedVote(bobsKey, bob, 1, VotingContract.VoteType.FOR, 100, block.timestamp);
        votes[1] = _createSignedVote(alicesKey, alice, 1, VotingContract.VoteType.AGAINST, 100, block.timestamp);

        // ensure alice has funds
        mockSNT.transfer(alice, 1000);
        votingContract.castVotes(votes);

        roomVoters = votingContract.listRoomVoters(1);
        assertEq(roomVoters.length, 2);
        assertEq(roomVoters[0], bob);
        assertEq(roomVoters[1], alice);
    }
}

contract GetVotingHistoryTest is VotingContractTest {
    function setUp() public virtual override {
        VotingContractTest.setUp();
    }

    function test_GetVotingHistory() public {
        VotingContract.VotingRoom[] memory votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms.length, 0);

        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms.length, 1);
        assertEq(votingRooms[0].community, communityID1);
        assertEq(votingRooms[0].roomNumber, 1);
        assertEq(uint256(votingRooms[0].voteType), 1);
        assertEq(votingRooms[0].finalized, false);
        assertEq(votingRooms[0].totalVotesFor, 100);
        assertEq(votingRooms[0].totalVotesAgainst, 0);

        skip(votingWithVerificationLength + 1);
        votingContract.finalizeVotingRoom(1);

        // make sure enough time has passed to initialize another voting room
        skip(timeBetweenVoting + 1);
        votingContract.initializeVotingRoom(VotingContract.VoteType.AGAINST, communityID1, 200);

        votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms.length, 2);
        assertEq(votingRooms[0].totalVotesFor, 100);
        assertEq(votingRooms[0].finalized, true);

        assertEq(votingRooms[1].community, communityID1);
        assertEq(votingRooms[1].roomNumber, 2);
        assertEq(uint256(votingRooms[1].voteType), 0);
        assertEq(votingRooms[1].finalized, false);
        assertEq(votingRooms[1].totalVotesFor, 200);
        assertEq(votingRooms[1].totalVotesAgainst, 0);
    }
}

contract InitializeVotingRoomTest is VotingContractTest {
    function setUp() public virtual override {
        VotingContractTest.setUp();
    }

    function test_RevertWhen_VoteAlreadyOngoing() public {
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);
        vm.expectRevert(bytes("vote already ongoing"));
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);
    }

    function test_RevertWhen_CommunityIsNotInDirectory() public {
        // initializing a voting room with VoteType.AGAINST requires `publicKey`
        // to be in the directory
        vm.expectRevert(bytes("Community not in directory"));
        votingContract.initializeVotingRoom(VotingContract.VoteType.AGAINST, communityID1, 100);
    }

    function test_RevertWhen_CommunityIsAlreadyInDirectory() public {
        vm.prank(address(votingContract));
        directoryContract.addCommunity(communityID1);
        vm.expectRevert(bytes("Community already in directory"));
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);
    }

    function test_RevertWhen_SenderHasNotEnoughFunds() public {
        // alice doesn't have any MockSNT
        vm.prank(alice);
        vm.expectRevert(bytes("not enough token"));
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);
    }

    function test_RevertWhen_TimeBetweenVotingHasNotPassed() public {
        // vote community `communityID1` into the directory
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);
        // fast forward such that voting time has passed
        skip(votingWithVerificationLength + 1);
        votingContract.finalizeVotingRoom(1);

        vm.expectRevert(bytes("Community was in a vote recently"));
        // community is in the directory now, so cause the expected revert
        // we need to initilalize a voting room to vote the community out of the directory
        votingContract.initializeVotingRoom(VotingContract.VoteType.AGAINST, communityID1, 100);
    }

    function test_InitializeVotingRoom() public {
        vm.expectEmit(false, false, false, true);
        emit VotingRoomStarted(1, communityID1);
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        uint256[] memory votingRooms = votingContract.getActiveVotingRooms();
        assertEq(votingRooms.length, 1);
        assertEq(votingRooms[0], 1);

        VotingContract.VotingRoom memory votingRoom = votingContract.getActiveVotingRoom(communityID1);
        assertEq(votingRoom.community, communityID1);
        assertEq(votingRoom.roomNumber, 1);
        assertEq(uint256(votingRoom.voteType), 1);
        assertEq(votingRoom.finalized, false);
        assertEq(votingRoom.totalVotesFor, 100);
        assertEq(votingRoom.totalVotesAgainst, 0);

        address[] memory roomVoters = votingContract.listRoomVoters(1);
        assertEq(roomVoters.length, 1);
        assertEq(roomVoters[0], address(this));
    }
}

contract FinalizeVotingRoomTest is VotingContractTest {
    function setUp() public virtual override {
        VotingContractTest.setUp();
    }

    function test_RevertWhen_VoteStillOngoing() public {
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);
        vm.expectRevert(bytes("vote still ongoing"));
        votingContract.finalizeVotingRoom(1);
    }

    function test_RevertWhen_VoteAlreadyFinalized() public {
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);
        skip(votingWithVerificationLength + 1);
        votingContract.finalizeVotingRoom(1);
        vm.expectRevert(bytes("vote already finalized"));
        votingContract.finalizeVotingRoom(1);
    }

    function test_FinalizeVotingRoom() public {
        uint256 startAt = block.timestamp;
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        skip(votingWithVerificationLength + 1);

        // finalize voting room
        vm.expectEmit(false, false, false, true);
        emit VotingRoomFinalized(1, communityID1, true, VotingContract.VoteType.FOR);
        votingContract.finalizeVotingRoom(1);

        uint256[] memory activeVotingRooms = votingContract.getActiveVotingRooms();
        assertEq(activeVotingRooms.length, 0);

        // check if voting room is finalized and community lives in directory
        VotingContract.VotingRoom[] memory votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms.length, 1);
        assertEq(votingRooms[0].community, communityID1);
        assertEq(votingRooms[0].finalized, true);
        assertEq(votingRooms[0].endAt, startAt + votingWithVerificationLength + 1);

        assert(directoryContract.isCommunityInDirectory(communityID1));
    }

    function test_FinalizeVotingRoom_ShouldIgnoreVoteIfVoterHasInsufficientFunds() public {
        // initialize voting room as bob who has funds
        vm.startPrank(bob);
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        // remove bob's funds
        mockSNT.transfer(address(mockSNT), mockSNT.balanceOf(bob));
        assertEq(mockSNT.balanceOf(bob), 0);

        // fast forward to finalize vote
        skip(votingWithVerificationLength + 1);

        // finalize voting room
        vm.expectEmit(false, false, false, true);
        emit NotEnoughToken(1, bob);
        vm.expectEmit(false, false, false, true);
        emit VotingRoomFinalized(1, communityID1, false, VotingContract.VoteType.FOR);
        votingContract.finalizeVotingRoom(1);

        VotingContract.VotingRoom[] memory votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms.length, 1);
        assertEq(votingRooms[0].community, communityID1);
        assertEq(votingRooms[0].finalized, true);

        // ensure vote has been ignored
        assertEq(votingRooms[0].totalVotesFor, 0);
        assertEq(directoryContract.isCommunityInDirectory(communityID1), false);
    }
}

contract CastVotesTest is VotingContractTest {
    function setUp() public virtual override {
        VotingContractTest.setUp();
    }

    function test_RevertWhen_VotingRoomHasBeenClosedAlready() public {
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);
        skip(votingWithVerificationLength + 1);

        VotingContract.SignedVote[] memory votes = new VotingContract.SignedVote[](1);
        votes[0] = _createSignedVote(bobsKey, bob, 1, VotingContract.VoteType.FOR, 200, block.timestamp);
        vm.expectRevert(bytes("vote closed"));
        votingContract.castVotes(votes);
    }

    function test_RevertWhen_InvalidVoteTimestamp() public {
        uint256 voteTimestamp = block.timestamp;
        VotingContract.SignedVote[] memory votes = new VotingContract.SignedVote[](1);
        votes[0] = _createSignedVote(bobsKey, bob, 1, VotingContract.VoteType.FOR, 200, voteTimestamp);

        // fast forward, such that vote timestamp will be earlier than the
        // voting room's startAt
        skip(1000);
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        vm.expectRevert(bytes("invalid vote timestamp"));
        votingContract.castVotes(votes);

        // now create another failing vote that has a newer timestamp than the
        // voting room's verificationStartAt
        skip(votingLength + 1);
        votes[0] = _createSignedVote(bobsKey, bob, 1, VotingContract.VoteType.FOR, 200, block.timestamp);
        vm.expectRevert(bytes("invalid vote timestamp"));
        votingContract.castVotes(votes);
    }

    function test_CastVotes_EmitInvalidSignature() public {
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        VotingContract.SignedVote[] memory votes = new VotingContract.SignedVote[](1);
        // create broken signature with bob's key but alice's address
        votes[0] = _createSignedVote(bobsKey, alice, 1, VotingContract.VoteType.FOR, 200, block.timestamp);

        vm.expectEmit(false, false, false, true);
        emit InvalidSignature(1, alice);
        votingContract.castVotes(votes);
    }

    function test_CastVotes_EmitAlreadyVoted() public {
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        VotingContract.SignedVote[] memory votes = new VotingContract.SignedVote[](1);
        votes[0] = _createSignedVote(bobsKey, bob, 1, VotingContract.VoteType.FOR, 100, block.timestamp);
        votingContract.castVotes(votes);

        VotingContract.VotingRoom[] memory votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms.length, 1);
        assertEq(votingRooms[0].community, communityID1);
        assertEq(votingRooms[0].totalVotesFor, 200);

        // try voting again
        vm.expectEmit(false, false, false, true);
        emit AlreadyVoted(1, bob);
        votingContract.castVotes(votes);

        votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms[0].totalVotesFor, 200);

        // try voting as alice
        votes[0] = _createSignedVote(alicesKey, alice, 1, VotingContract.VoteType.FOR, 200, block.timestamp);

        // ensure alice has funds
        mockSNT.transfer(alice, 10_000);
        votingContract.castVotes(votes);

        // check if voting wen through
        votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms[0].totalVotesFor, 400);
    }

    function test_CastVotes_EmitNotEnoughToken() public {
        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        VotingContract.SignedVote[] memory votes = new VotingContract.SignedVote[](1);
        votes[0] = _createSignedVote(bobsKey, bob, 1, VotingContract.VoteType.FOR, 200, block.timestamp);

        // remove bob's funds
        vm.startPrank(bob);
        mockSNT.transfer(address(mockSNT), mockSNT.balanceOf(bob));
        assertEq(mockSNT.balanceOf(bob), 0);

        vm.expectEmit(false, false, false, true);
        emit NotEnoughToken(1, bob);
        votingContract.castVotes(votes);

        VotingContract.VotingRoom[] memory votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms.length, 1);
        assertEq(votingRooms[0].community, communityID1);
        assertEq(votingRooms[0].totalVotesFor, 100);
    }

    function test_CastVotes() public {
        // ensure alice has funds
        mockSNT.transfer(alice, 1000);

        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        VotingContract.SignedVote[] memory votes = new VotingContract.SignedVote[](2);
        votes[0] = _createSignedVote(bobsKey, bob, 1, VotingContract.VoteType.FOR, 100, block.timestamp);
        votes[1] = _createSignedVote(alicesKey, alice, 1, VotingContract.VoteType.AGAINST, 200, block.timestamp);

        vm.expectEmit(false, false, false, true);
        emit VoteCast(1, bob);
        vm.expectEmit(false, false, false, true);
        emit VoteCast(1, alice);
        votingContract.castVotes(votes);

        VotingContract.VotingRoom[] memory votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms.length, 1);
        assertEq(votingRooms[0].community, communityID1);
        assertEq(votingRooms[0].totalVotesFor, 200);
        assertEq(votingRooms[0].totalVotesAgainst, 200);

        skip(votingWithVerificationLength + 1);
        vm.expectEmit(false, false, false, true);
        emit VotingRoomFinalized(1, communityID1, false, VotingContract.VoteType.FOR);
        votingContract.finalizeVotingRoom(1);

        votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms[0].community, communityID1);
        assertEq(votingRooms[0].finalized, true);

        // contract didn't make it into directory
        assertEq(directoryContract.isCommunityInDirectory(communityID1), false);

        // fast forward to initialize a new voting room
        skip(timeBetweenVoting + 1);

        votingContract.initializeVotingRoom(VotingContract.VoteType.FOR, communityID1, 100);

        votes[0] = _createSignedVote(bobsKey, bob, 2, VotingContract.VoteType.FOR, 500, block.timestamp);
        votes[1] = _createSignedVote(alicesKey, alice, 2, VotingContract.VoteType.FOR, 400, block.timestamp);

        vm.expectEmit(false, false, false, true);
        emit VoteCast(2, bob);
        vm.expectEmit(false, false, false, true);
        emit VoteCast(2, alice);
        votingContract.castVotes(votes);

        votingRooms = votingContract.getVotingHistory(communityID1);
        assertEq(votingRooms[1].community, communityID1);
        assertEq(votingRooms[1].finalized, false);
        assertEq(votingRooms[1].totalVotesFor, 1000);
        assertEq(votingRooms[1].totalVotesAgainst, 0);

        skip(votingWithVerificationLength + 1);

        vm.expectEmit(false, false, false, true);
        emit VotingRoomFinalized(2, communityID1, true, VotingContract.VoteType.FOR);
        votingContract.finalizeVotingRoom(2);
    }
}
