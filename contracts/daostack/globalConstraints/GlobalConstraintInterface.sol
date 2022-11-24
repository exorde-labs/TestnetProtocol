// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

interface   GlobalConstraintInterface  {
    enum CallPhase {
        Pre,
        Post,
        PreAndPost
    }

    function pre(
        address _scheme,
        bytes32 _params,
        bytes32 _method
    ) external returns (bool);

    function post(
        address _scheme,
        bytes32 _params,
        bytes32 _method
    ) external returns (bool);

    /**
     * @dev when return if this globalConstraints is pre, post or both.
     * @return CallPhase enum indication  Pre, Post or PreAndPost.
     */
    function when() external returns (CallPhase);
}
