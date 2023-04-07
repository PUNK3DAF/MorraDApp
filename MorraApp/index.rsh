"reach 0.1";
const [isHand, ZERO, ONE, TWO, THREE, FOUR, FIVE] = makeEnum(6); // Define constants for all the possible numbers that can be played
const [
  isGuess,
  GUESS_ZERO,
  GUESS_ONE,
  GUESS_TWO,
  GUESS_THREE,
  GUESS_FOUR,
  GUESS_FIVE,
  GUESS_SIX,
  GUESS_SEVEN,
  GUESS_EIGHT,
  GUESS_NINE,
  GUESS_TEN,
] = makeEnum(11); // Define constants for all the possible guesses
const [isOutcome, B_WINS, DRAW, A_WINS] = makeEnum(3); // Define constants for the possible outcomes of the game

// Define a function to determine the winner of a game given the hands and guesses of the players
const winner = (handA, handB, guessA, guessB) => {
  // If the players guess the same number, the game is a draw
  if (guessA == guessB) {
    const outcome = DRAW;
    return outcome;
  }
  // If the sum of the players' hands equals Andrew's guess, Andrew wins
  else if (handA + handB == guessA) {
    const outcome = A_WINS;
    return outcome;
  }
  // If the sum of the players' hands equals Blake's guess, Blake wins
  else if (handA + handB == guessB) {
    const outcome = B_WINS;
    return outcome;
  }
  // Otherwise, the game is a draw
  else {
    const outcome = DRAW;
    return outcome;
  }
};

// Assert that the function returns the correct outcome for several specific cases
assert(winner(ZERO, FIVE, GUESS_TWO, GUESS_FIVE) == B_WINS);
assert(winner(FIVE, ZERO, GUESS_FIVE, GUESS_ZERO) == A_WINS);
assert(winner(ZERO, ONE, GUESS_THREE, GUESS_FOUR) == DRAW);
assert(winner(ONE, ONE, GUESS_ONE, GUESS_ONE) == DRAW);

// Assert that the function returns a valid outcome for all possible combinations of hands and guesses
forall(UInt, (handA) =>
  forall(UInt, (handB) =>
    forall(UInt, (guessA) =>
      forall(UInt, (guessB) =>
        assert(isOutcome(winner(handA, handB, guessA, guessB)))
      )
    )
  )
);

// Assert that the function returns a draw when both players guess the same number
forall(UInt, (handA) =>
  forall(UInt, (handB) =>
    forall(UInt, (guess) => assert(winner(handA, handB, guess, guess) == DRAW))
  )
);

// Define an object representing the functions that both players have in common
const Player = {
  ...hasRandom, // Include the hasRandom object, which provides access to random numbers
  getHand: Fun([], UInt), // A function to get the player's hand
  getGuess: Fun([UInt], UInt), // A function to get the player's guess
  seeWinning: Fun([UInt], Null), // A function to inform the player of the winning number
  seeOutcome: Fun([UInt], Null), // A function to inform the player of the outcome of the game
  informTimeout: Fun([], Null), // A function to inform the player that the game has timed out
};
// Define deadline for timeout
const DEADLINE = 30;

export const main = Reach.App(() => {
  // Define participants
  const A = Participant("Andrew", {
    ...Player, // Inherit propeties from Player
    wager: UInt, // Define property wager as a UInt
  });
  const B = Participant("Blake", {
    ...Player, // Inherit properties from Player
    acceptWager: Fun([UInt], Null), // Define function acceptWager that takes a UInt argument and returns Null
  });
  init(); // Initialize the Reach app

  // Define a function that will be called if the deadline is exceeded
  const informTimeout = () => {
    each([A, B], () => {
      interact.informTimeout(); // Add informTimeout function to each participant
    });
  };
  A.only(() => {
    const wager = declassify(interact.wager); // Declassify Andrew's wager to prepare it for publishing
  });
  A.publish(wager).pay(wager); // Publish Andrew's wager and pay
  commit(); // Commit the state of the Reach app

  B.only(() => {
    interact.acceptWager(wager); // Blake accepts the wager
  });
  B.pay(wager).timeout(
    relativeTime(DEADLINE), // Set the timeout for the wager
    () => closeTo(A, informTimeout) // If 30 seconds pass, informTimeout is called and Andrew gets his money back
  );

  // Define the outcome variable to be DRAW by default
  var outcome = DRAW;
  invariant(balance() == 2 * wager && isOutcome(outcome)); // Variables that won't be changed before, during and after the while loop
  // Balance of the contract stays the same and outcome needs to be a value that's in isOutcome enum
  // Loop until we have a winner
  while (outcome == DRAW) {
    // Commit to playing
    commit();

    // Andrew plays
    A.only(() => {
      // Get the hand and guess of Andrew
      const _handA = interact.getHand();
      const _guessA = interact.getGuess(_handA);

      // Encrypt Andrew's hand and guess
      const [_commitA, _saltA] = makeCommitment(interact, _handA);
      const commitA = declassify(_commitA);
      const [_guessCommitA, _guessSaltA] = makeCommitment(interact, _guessA);
      const guessCommitA = declassify(_guessCommitA);
    });

    // Publish Andrew's encrypted hand and guess
    A.publish(commitA).timeout(relativeTime(DEADLINE), () =>
      closeTo(B, informTimeout)
    );
    commit();

    A.publish(guessCommitA).timeout(relativeTime(DEADLINE), () =>
      closeTo(B, informTimeout)
    );
    commit();

    // Ensure that Blake cannot know Andrew's hand and guess
    unknowable(B, A(_handA, _saltA));
    unknowable(B, A(_guessA, _guessSaltA));

    // Blake plays
    B.only(() => {
      // Get the hand and guess of Blake
      const _handB = interact.getHand();
      const _guessB = interact.getGuess(_handB);

      // Encrypt Blake's hand and guess
      const handB = declassify(_handB);
      const guessB = declassify(_guessB);
    });

    // Publish Blake's hand and guess
    B.publish(handB, guessB).timeout(relativeTime(DEADLINE), () =>
      closeTo(A, informTimeout)
    );
    commit();

    // Decrypt Andrew's encrypted hand and guess
    A.only(() => {
      const [saltA, handA] = declassify([_saltA, _handA]);
      const [guessSaltA, guessA] = declassify([_guessSaltA, _guessA]);
    });

    // Publish Andrew's hand
    A.publish(saltA, handA).timeout(relativeTime(DEADLINE), () =>
      closeTo(B, informTimeout)
    );

    // Check that Andrew has published the correct hand value
    checkCommitment(commitA, saltA, handA);
    commit();

    // Publishing Andrew's guess
    A.publish(guessSaltA, guessA).timeout(relativeTime(DEADLINE), () =>
      closeTo(B, informTimeout)
    );

    // Check that Andrew has published the correct guess value
    checkCommitment(guessCommitA, guessSaltA, guessA);

    commit();

    // Determine the winning outcome
    A.only(() => {
      const WinningNumber = handA + handB;
      interact.seeWinning(WinningNumber);
    });

    // Publish the winning outcome
    A.publish(WinningNumber).timeout(relativeTime(DEADLINE), () =>
      closeTo(A, informTimeout)
    );

    // Determine the outcome of the game
    outcome = winner(handA, handB, guessA, guessB);
    continue; // Proceed to the next loop
  }

  // Assert that the outcome cannot be DRAW
  assert(outcome == A_WINS || outcome == B_WINS);
  // Send money to the winner
  transfer(2 * wager).to(outcome == A_WINS ? A : B);
  commit();

  each([A, B], () => {
    interact.seeOutcome(outcome); // Send the results to both participants
  });
  exit(); // Exit the game
});
