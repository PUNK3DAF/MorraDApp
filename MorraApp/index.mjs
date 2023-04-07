// Import necessary modules
import { loadStdlib, ask } from "@reach-sh/stdlib";
import * as backend from "./build/index.main.mjs";

// Load the Reach standard library
const stdlib = loadStdlib();

// Ask the user if they are Andrew
const isAndrew = await ask.ask(`Are you Andrew?`, ask.yesno);

// Set the value of 'who' based on the user's response to the previous question
const who = isAndrew ? "Andrew" : "Blake";

// Print a message indicating that the Morra game is starting
console.log(`Starting Morra as ${who}`);

// Initialize the account variable
let acc = null;

// Ask the user if they want to create an account
const createAcc = await ask.ask(
  `Would you like to create an account?`,
  ask.yesno
);

// If the user wants to create an account, create a new test account with 1000 currency
// If not, ask for the user's account secret and create an account from the secret
if (createAcc) {
  acc = await stdlib.newTestAccount(stdlib.parseCurrency(1000));
} else {
  const secret = await ask.ask(`What is your account secret?`, (x) => x);
  acc = await stdlib.newAccountFromSecret(secret);
}

// Initialize the ctc variable
let ctc = null;

// If the user is Andrew, deploy the contract and log the contract information
// Otherwise, ask the user to paste the contract information and create the contract
if (isAndrew) {
  ctc = acc.contract(backend);
  ctc.getInfo().then((info) => {
    console.log(`The contract is deployed as = ${JSON.stringify(info)}`);
  });
} else {
  const info = await ask.ask(
    `Please paste the contract information:`,
    JSON.parse
  );
  ctc = acc.contract(backend, info);
}

// Define a function 'fmt' that takes a number 'x' and formats it as a currency string with 4 decimal places.
const fmt = (x) => stdlib.formatCurrency(x, 4);

// Define an asynchronous function 'getBalance' that retrieves the balance of the current account and formats it using the 'fmt' function defined above.
const getBalance = async () => fmt(await stdlib.balanceOf(acc));

// Call the 'getBalance' function and store the result in 'before'.
const before = await getBalance();

// Log a message to the console that shows the current account balance.
console.log(`Your balance is ${before}`);

// Create a new object 'interact' that has the same properties as 'stdlib.hasRandom'.
const interact = { ...stdlib.hasRandom };

// Define a function 'informTimeout' that logs a message to the console when a timeout occurs, then exits the process with a non-zero status code.
interact.informTimeout = () => {
  console.log(`There was a timeout.`);
  process.exit(1);
};

// If the variable 'isAndrew' is true, ask the user how much they want to wager and store the result in 'amt'.
// Set the 'wager' property of 'interact' to 'amt' and the 'deadline' property to a value depending on the 'connector' property of 'stdlib'.
if (isAndrew) {
  const amt = await ask.ask(
    `How much do you want to wager?`,
    stdlib.parseCurrency
  );
  interact.wager = amt;
  interact.deadline = { ETH: 100, ALGO: 100, CFX: 1000 }[stdlib.connector];
}

// If the variable 'isAndrew' is false, define an asynchronous function 'acceptWager' that asks the user if they accept a wager of a certain amount.
// If the user does not accept, exit the process with a status code of 0.
else {
  interact.acceptWager = async (amt) => {
    const accepted = await ask.ask(
      `Do you accept the wager of ${fmt(amt)}?`,
      ask.yesno
    );
    if (!accepted) {
      process.exit(0);
    }
  };
}

// Define three arrays: 'HAND', 'GUESS', and 'OUTCOME', that store possible values for different game parameters.
const HAND = [0, 1, 2, 3, 4, 5];
const GUESS = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const OUTCOME = ["Blake wins", "Draw", "Andrew wins"];

// Define a function 'getHand' that asks the user what hand they want to play, validates their input, logs a message to the console, and returns the chosen hand.
interact.getHand = async () => {
  const hand = await ask.ask(`What hand will you play?`, (x) => {
    const hand = HAND[x];
    if (hand === undefined) {
      throw Error(`${hand} is an invalid hand`);
    }
    return hand;
  });
  console.log(`You played ${HAND[hand]}`);
  return hand;
};

// Define an asynchronous function called `getGuess` on the `interact` object that takes a `hand` parameter.
interact.getGuess = async (hand) => {
  // Await an answer to the question "What hand will you guess?" and assign it to `guess`.
  const guess = await ask.ask(`What hand will you guess?`, (x) => {
    // Get the `guess` value corresponding to the `x` index of the `GUESS` array, and assign it to `guess`.
    const guess = GUESS[x];
    // If `guess` is undefined, throw an error with a message that includes `guess`.
    if (guess === undefined) {
      throw Error(`${guess} is an invalid guess`);
    }
    // Return the value of `guess`.
    return guess;
  });
  // Print a message to the console indicating the guess the user made.
  console.log(`You guessed ${GUESS[guess]}`);
  // Return the value of `guess`.
  return guess;
};

// Define a function called `seeWinning` on the `interact` object that takes a `winningNumber` parameter.
interact.seeWinning = (winningNumber) => {
  // Print a message to the console indicating the total hand thrown.
  console.log(`Actual total hand thrown: ${winningNumber}`);
};

// Define a function called `seeOutcome` on the `interact` object that takes an `outcome` parameter.
interact.seeOutcome = (outcome) => {
  // Print a message to the console indicating the outcome of the game.
  console.log(`The outcome is ${OUTCOME[outcome]}`);
};

// Assign a reference to a function to the variable `part`, based on the value of the `isAndrew` variable.
const part = isAndrew ? ctc.p.Andrew : ctc.p.Blake;
// Invoke the `part` function, passing the `interact` object as an argument, and await the result.
await part(interact);

// Get the user's account balance after the game.
const after = await getBalance();
// Print a message to the console indicating the user's new account balance.
console.log(`Your balance is now ${after}`);

// Indicate that we are done using the `ask` library.
ask.done();
