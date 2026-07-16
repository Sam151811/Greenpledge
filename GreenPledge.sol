// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/**
 * @title GreenPledge
 * @notice Stake-backed climate commitments. Users pledge a green action and
 *         stake ETH on it. A named verifier attests success or failure:
 *         - Success: staker reclaims stake + is minted an ERC-1155 impact credit.
 *         - Failure: stake is forwarded to a climate fund address.
 *         - Verifier never shows up: staker can reclaim after a grace period
 *           (no credit minted) — prevents verifier griefing.
 *
 * @dev Behavioral-economics rationale: commitment devices + loss aversion.
 *      Verification here is social attestation; the roadmap is to replace it
 *      with hardware-signed data + ZK proofs (zkVerify) for measurable actions.
 */
contract GreenPledge is ERC1155 {
    // ---------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------

    enum Status { Active, Succeeded, Failed, Expired }

    // ERC-1155 token ids double as pledge categories
    uint256 public constant TRANSPORT = 1; // e.g. cycle / public transport week
    uint256 public constant DIET      = 2; // e.g. meat-free week
    uint256 public constant ENERGY    = 3; // e.g. reduce household kWh
    uint256 public constant NATURE    = 4; // e.g. tree planting, cleanup
    uint256 public constant OTHER     = 5;

    struct Pledge {
        address creator;
        address verifier;
        uint96  stake;        // fits any realistic testnet stake
        uint64  deadline;     // unix timestamp pledge must be completed by
        uint8   category;     // 1..5, doubles as ERC-1155 token id
        Status  status;
        string  description;  // human-readable pledge text
    }

    // ---------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------

    address public immutable climateFund;     // receives forfeited stakes
    uint64  public constant GRACE_PERIOD = 3 days;

    uint256 public nextPledgeId;
    mapping(uint256 => Pledge) public pledges;

    // ---------------------------------------------------------------
    // Events (indexed for The Graph subgraph)
    // ---------------------------------------------------------------

    event PledgeCreated(
        uint256 indexed pledgeId,
        address indexed creator,
        address indexed verifier,
        uint256 stake,
        uint64  deadline,
        uint8   category,
        string  description
    );

    event PledgeResolved(
        uint256 indexed pledgeId,
        address indexed creator,
        Status  status,
        uint256 stake
    );

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ZeroStake();
    error ZeroAddress();
    error BadCategory();
    error BadDeadline();
    error NotVerifier();
    error NotCreator();
    error NotActive();
    error DeadlinePassed();
    error GraceNotOver();
    error TransferFailed();

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @param _climateFund address that receives forfeited stakes
    /// @param _uri ERC-1155 metadata URI template (can be a placeholder)
    constructor(address _climateFund, string memory _uri) ERC1155(_uri) {
        if (_climateFund == address(0)) revert ZeroAddress();
        climateFund = _climateFund;
        nextPledgeId = 1;
    }

    // ---------------------------------------------------------------
    // Core flow
    // ---------------------------------------------------------------

    /// @notice Create a pledge by staking ETH on a green action.
    function createPledge(
        address verifier,
        uint64  deadline,
        uint8   category,
        string calldata description
    ) external payable returns (uint256 pledgeId) {
        if (msg.value == 0 || msg.value > type(uint96).max) revert ZeroStake();
        if (verifier == address(0) || verifier == msg.sender) revert ZeroAddress();
        if (category < TRANSPORT || category > OTHER) revert BadCategory();
        if (deadline <= block.timestamp) revert BadDeadline();

        pledgeId = nextPledgeId++;
        pledges[pledgeId] = Pledge({
            creator:     msg.sender,
            verifier:    verifier,
            stake:       uint96(msg.value),
            deadline:    deadline,
            category:    category,
            status:      Status.Active,
            description: description
        });

        emit PledgeCreated(
            pledgeId, msg.sender, verifier,
            msg.value, deadline, category, description
        );
    }

    /// @notice Verifier attests the outcome. Allowed up to deadline + grace.
    function attest(uint256 pledgeId, bool success) external {
        Pledge storage p = pledges[pledgeId];
        if (msg.sender != p.verifier) revert NotVerifier();
        if (p.status != Status.Active) revert NotActive();
        if (block.timestamp > p.deadline + GRACE_PERIOD) revert DeadlinePassed();

        uint256 stake = p.stake;

        if (success) {
            p.status = Status.Succeeded;
            _mint(p.creator, p.category, 1, ""); // impact credit badge
            emit PledgeResolved(pledgeId, p.creator, Status.Succeeded, stake);
            _pay(p.creator, stake);
        } else {
            p.status = Status.Failed;
            emit PledgeResolved(pledgeId, p.creator, Status.Failed, stake);
            _pay(climateFund, stake); // loss aversion, made concrete
        }
    }

    /// @notice If the verifier never attests, creator reclaims stake after
    ///         deadline + grace. No credit is minted.
    function reclaimExpired(uint256 pledgeId) external {
        Pledge storage p = pledges[pledgeId];
        if (msg.sender != p.creator) revert NotCreator();
        if (p.status != Status.Active) revert NotActive();
        if (block.timestamp <= p.deadline + GRACE_PERIOD) revert GraceNotOver();

        p.status = Status.Expired;
        uint256 stake = p.stake;
        emit PledgeResolved(pledgeId, p.creator, Status.Expired, stake);
        _pay(p.creator, stake);
    }

    // ---------------------------------------------------------------
    // Views & internals
    // ---------------------------------------------------------------

    function getPledge(uint256 pledgeId) external view returns (Pledge memory) {
        return pledges[pledgeId];
    }

    /// @dev checks-effects-interactions respected by all callers
    function _pay(address to, uint256 amount) internal {
        (bool ok, ) = payable(to).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @dev Impact credits are soulbound badges, not tradeable offsets.
    ///      This is deliberate: unverified credits must not enter markets.
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        require(from == address(0), "GreenPledge: credits are soulbound");
        super._update(from, to, ids, values);
    }
}
