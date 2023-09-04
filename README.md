# User Flow

```mermaid
graph TD;
    subgraph Users
        User1;
        User2;
    end

    User1-->A["CreateLock(uint value, uint lockduration): <br> Creates lock and mints an NFT representing voting power"];
    User2-->B["CreateLockForUser(uint value, uint lockduration, address _to): <br> Creates lock on behalf of _to address "];
    B-->A;
    A-->C["IncreaseAmount(uint tokenId, uint amount): <br> Increases the staking amount for the owner of tokenId. <br> which inreturn increases the voting power"];
    A-->D["IncreaseUnlockTime(uint tokenId, uint newUnlockTime): <br> Increases the unlock time for the owner of tokenId. <br> which inreturn increases the voting power"];
    A-->E["Withdraw(uint tokenId): <br> withdraw staked amount after lock expired and burn the NFT tokenId"];
```

<br><br>

## Test Coverage report:

Pre-requisite:

- genhtml
- lcov

To access the test coverage report, run the command

```console
forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage --ignore-errors category
```

Now, access the coverage/index.html file to access the detailed reports
