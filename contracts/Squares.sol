pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './interfaces/IScoreOracle.sol';
import './KnowsSquares.sol';
import './KnowsConstants.sol';
import './KnowsTime.sol';

contract Squares is KnowsConstants, KnowsTime, KnowsSquares {
    using SafeMath for uint;

    function Squares(IScoreOracle _oracle) public {
        oracle = _oracle;
    }

    // the oracle for the scores
    IScoreOracle public oracle;

    // staked ether for each player and each box
    mapping(address => uint[10][10]) public boxStakesByUser;

    // total stakes for each box
    uint[10][10] public totalBoxStakes;

    // the total stakes for each user
    mapping(address => uint) public totalUserStakes;

    // the overall total of money stakes in the grid
    uint public totalStakes;

    event LogBet(address indexed better, uint indexed home, uint indexed away, uint stake);

    function bet(uint home, uint away) public payable isValidSquare(home, away) {
        require(msg.value > 0);
        require(currentTime() < GAME_START_TIME);

        // the stake is the message value
        uint stake = msg.value;

        // add the stake amount to the overall total
        totalStakes = totalStakes.add(stake);

        // add their stake to the total user stakes
        totalUserStakes[msg.sender] = totalUserStakes[msg.sender].add(stake);

        // add their stake to their own accounting
        boxStakesByUser[msg.sender][home][away] = boxStakesByUser[msg.sender][home][away].add(stake);

        // add it to the total stakes as well
        totalBoxStakes[home][away] = totalBoxStakes[home][away].add(stake);

        LogBet(msg.sender, home, away, stake);
    }

    event LogPayout(address indexed winner, uint winnings);

    // called by the winners to collect winnings for a box
    function collectWinnings(uint home, uint away) public isValidSquare(home, away) {
        sendWinningsTo(msg.sender, home, away);
    }

    // called by anyone to send winnings for a address box, only after all the quarters are reported
    function sendWinningsTo(address winner, uint home, uint away) public isValidSquare(home, away) {
        // score must be finalized
        require(oracle.isFinalized());

        // the box wins and the total wins are used to calculate the percentage of the total stake that the box is worth
        var (boxWins, totalWins) = oracle.getBoxWins(home, away);

        uint userStake = boxStakesByUser[winner][home][away];
        uint boxStake = totalBoxStakes[home][away];

        uint winnings = userStake.mul(totalStakes).mul(boxWins).div(totalWins).div(boxStake);

        require(winnings > 0);

        // clear their stakes - can only collect once
        boxStakesByUser[winner][home][away] = 0;

        winner.transfer(winnings);

        LogPayout(winner, winnings);
    }
}