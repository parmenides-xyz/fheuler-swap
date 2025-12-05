"use client";

import { useCallback, useState, useEffect } from "react";
import { cofhejs, Encryptable, FheTypes } from "cofhejs/web";
import { useReadContract } from "wagmi";
import type { ContractFunctionParameters } from "viem";
import {
  Transaction,
  TransactionButton,
} from "@coinbase/onchainkit/transaction";
import type { LifecycleStatus } from "@coinbase/onchainkit/transaction";
import { CONTRACT_ADDRESS, CONTRACT_ABI } from "../contracts/deployedContracts";

// Info icon SVG
const InfoIcon = ({ className }: { className?: string }) => (
  <svg
    className={className}
    fill="none"
    viewBox="0 0 24 24"
    stroke="currentColor"
  >
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={2}
      d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
    />
  </svg>
);

/**
 * EncryptedValue Component - Displays and decrypts encrypted values with toggle
 */
const EncryptedValue = <T extends FheTypes>({
  fheType,
  ctHash,
}: {
  fheType: T;
  ctHash: bigint | null | undefined;
}) => {
  const [value, setValue] = useState<string | null>(null);
  const [isDecrypting, setIsDecrypting] = useState(false);
  const [isVisible, setIsVisible] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Reset when ctHash changes (new counter value)
  useEffect(() => {
    setValue(null);
    setIsVisible(false);
    setErrorMessage(null);
  }, [ctHash]);

  const handleToggle = async () => {
    if (!ctHash || isDecrypting) return;

    // If we have a value, just toggle visibility
    if (value) {
      setIsVisible(!isVisible);
      return;
    }

    // Otherwise, decrypt first
    setIsDecrypting(true);
    setErrorMessage(null); // Clear any previous errors
    try {
      const decryptedValue = await cofhejs.unseal(ctHash, fheType);
      console.log(decryptedValue);

      if (decryptedValue.success) {
        setValue(decryptedValue.data!.toString());
        setIsVisible(true);
      } else {
        setErrorMessage(
          "You are not allowed to decrypt yet, interact with the contract first"
        );
      }
    } catch (error) {
      console.error("Decryption error:", error);
      setErrorMessage("An unexpected error occurred during decryption");
    } finally {
      setIsDecrypting(false);
    }
  };

  const renderContent = () => {
    if (isDecrypting) return "decrypting...";
    if (value && isVisible) return value;
    return "encryp*ed";
  };

  const showHint = !value && !isDecrypting && ctHash;
  const content = renderContent();

  return (
    <div className="flex flex-col flex-1 gap-2">
      <button
        onClick={handleToggle}
        disabled={!ctHash || isDecrypting}
        className="flex flex-1 px-4 sm:px-6 py-4 sm:py-5 items-center justify-center transition-all hover:scale-105 hover:opacity-90 disabled:hover:scale-100 disabled:hover:opacity-70 cursor-pointer min-h-[80px]"
        style={{
          borderRadius: "0",
          background:
            "linear-gradient(135deg, rgba(10, 217, 220, 0.1) 0%, rgba(10, 217, 220, 0.05) 100%)",
          border: "2px solid rgba(10, 217, 220, 0.3)",
        }}
      >
        <div className="flex flex-col items-center justify-center gap-2">
          <div className="flex items-center justify-center gap-2 sm:gap-3">
            {isDecrypting && (
              <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
            )}
            <span className="text-xl sm:text-2xl font-bold text-white font-(family-name:--font-clash) tracking-tight uppercase">
              {content.split("").map((char, idx) => (
                <span
                  key={idx}
                  className={char === "*" ? "text-fhenix-cyan" : ""}
                >
                  {char}
                </span>
              ))}
            </span>
          </div>
          {showHint && (
            <span className="text-xs sm:text-sm text-fhenix-cyan font-(family-name:--font-clash) opacity-70">
              Click to decrypt
            </span>
          )}
        </div>
      </button>
      {errorMessage && (
        <div
          className="px-3 sm:px-4 py-2 text-xs sm:text-sm text-center font-(family-name:--font-clash)"
          style={{
            backgroundColor: "rgba(239, 68, 68, 0.1)",
            border: "1px solid rgba(239, 68, 68, 0.3)",
            borderRadius: "0",
            color: "#fca5a5",
          }}
        >
          {errorMessage}
        </div>
      )}
    </div>
  );
};

/**
 * FHECounterComponent - A demonstration of Fully Homomorphic Encryption (FHE) in a web application
 *
 * This component showcases how to:
 * 1. Read encrypted values from a smart contract
 * 2. Display encrypted values using a specialized component
 * 3. Encrypt user input before sending to the blockchain
 * 4. Interact with FHE-enabled smart contracts
 *
 * The counter value is stored as an encrypted uint32 on the blockchain,
 * meaning the actual value is never revealed on-chain.
 */

export const FHECounter = () => {
  const [resetKey, setResetKey] = useState(0);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Get the refetch function to manually refresh the counter after transactions
  const { data: count, refetch } = useReadContract({
    address: CONTRACT_ADDRESS as `0x${string}`,
    abi: CONTRACT_ABI,
    functionName: "count",
  });

  const handleTransactionSuccess = useCallback(
    async (message: string) => {
      // Wait a bit for the blockchain to update
      await new Promise((resolve) => setTimeout(resolve, 1000));
      // Refetch the counter value
      await refetch();
      // Force reset of the encrypted value display
      setResetKey((prev) => prev + 1);
      // Show success message
      setSuccessMessage(message);
      // Auto-clear success message after 3 seconds
      setTimeout(() => setSuccessMessage(null), 3000);
    },
    [refetch]
  );

  return (
    <div
      className="flex flex-col px-4 sm:px-8 py-6 sm:py-8 items-center gap-4 w-full max-w-2xl mx-auto"
      style={{ backgroundColor: "#122531" }}
    >
      <h2 className="text-lg sm:text-xl font-semibold text-white font-(family-name:--font-clash) text-center">
        FHE Counter
      </h2>

      {successMessage && (
        <div
          className="w-full px-3 sm:px-4 py-2 text-xs sm:text-sm text-center font-(family-name:--font-clash)"
          style={{
            backgroundColor: "rgba(34, 197, 94, 0.1)",
            border: "1px solid rgba(34, 197, 94, 0.3)",
            borderRadius: "0",
            color: "#86efac",
          }}
        >
          {successMessage}
        </div>
      )}

      <SetCounterRow onSuccess={handleTransactionSuccess} />
      <div className="flex flex-col sm:flex-row w-full gap-3">
        <IncrementButton onSuccess={handleTransactionSuccess} />
        <DecrementButton onSuccess={handleTransactionSuccess} />
      </div>
      <EncryptedCounterDisplay
        count={count as bigint | undefined}
        resetKey={resetKey}
      />
    </div>
  );
};

/**
 * SetCounterRow Component
 *
 * Demonstrates the process of encrypting user input before sending it to the blockchain:
 * 1. User enters a number in the input field
 * 2. When "Set" is clicked, the number is encrypted using cofhejs
 * 3. The encrypted value is then sent to the smart contract
 *
 * This ensures the actual value is never exposed on the blockchain,
 * maintaining privacy while still allowing computations.
 */
const SetCounterRow = ({
  onSuccess,
}: {
  onSuccess: (message: string) => void;
}) => {
  const [input, setInput] = useState<string>("");

  const handleOnStatus = useCallback(
    (status: LifecycleStatus) => {
      console.log("Reset transaction status:", status);
      if (status.statusName === "success") {
        console.log(" Reset transaction successful");
        onSuccess(" Counter reset successfully!");
        setInput(""); // Clear input after success
      }
    },
    [onSuccess]
  );

  const callsCallback = useCallback(async () => {
    if (!input) return [];

    // Encrypt the input
    const encryptedInput = await cofhejs.encrypt([
      Encryptable.uint32(input),
    ] as const);

    const calls: ContractFunctionParameters[] = [
      {
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: CONTRACT_ABI as ContractFunctionParameters["abi"],
        functionName: "reset",
        args: [encryptedInput.data?.[0]],
      },
    ];

    return calls;
  }, [input]);

  return (
    <div className="flex flex-col sm:flex-row w-full gap-3">
      <input
        type="number"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        placeholder="Enter a number"
        className="flex-1 px-3 sm:px-4 py-3 bg-gray-800 text-white border-0 focus:outline-none font-(family-name:--font-clash) text-sm sm:text-base"
        style={{ borderRadius: "0" }}
      />
      <Transaction
        calls={callsCallback}
        onStatus={handleOnStatus}
        resetAfter={2000}
      >
        <TransactionButton
          disabled={!input}
          render={({ status, onSubmit, isDisabled }) => {
            const isPending = status === "pending";
            return (
              <button
                className={`px-4 sm:px-6 py-3 font-semibold uppercase tracking-widest transition-all font-(family-name:--font-clash) whitespace-nowrap text-sm sm:text-base w-full sm:w-auto ${
                  isPending || isDisabled || !input
                    ? "opacity-50 cursor-not-allowed"
                    : "hover:opacity-80"
                }`}
                style={{
                  backgroundColor: "#FFFFFF",
                  color: "#011623",
                  border: "none",
                  borderRadius: "0",
                }}
                onClick={onSubmit}
                disabled={isPending || isDisabled || !input}
              >
                {isPending && (
                  <span className="inline-block w-4 h-4 border-2 border-fhenix-dark border-t-transparent rounded-full animate-spin mr-2"></span>
                )}
                Reset
              </button>
            );
          }}
        />
      </Transaction>
    </div>
  );
};

/**
 * IncrementButton Component
 *
 * Demonstrates a simple operation on encrypted data.
 * The smart contract handles the increment operation on the encrypted value
 * without ever decrypting it, showcasing the power of FHE.
 */
const IncrementButton = ({
  onSuccess,
}: {
  onSuccess: (message: string) => void;
}) => {
  const handleOnStatus = useCallback(
    (status: LifecycleStatus) => {
      console.log("Increment transaction status:", status);
      if (status.statusName === "success") {
        console.log(" Increment transaction successful");
        onSuccess(" Counter incremented successfully!");
      }
    },
    [onSuccess]
  );

  const calls: ContractFunctionParameters[] = [
    {
      address: CONTRACT_ADDRESS as `0x${string}`,

      abi: CONTRACT_ABI as ContractFunctionParameters["abi"],
      functionName: "increment",
      args: [],
    },
  ];

  return (
    <Transaction
      calls={calls}
      onStatus={handleOnStatus}
      className="flex-1"
      resetAfter={2000}
    >
      <TransactionButton
        render={({ status, onSubmit, isDisabled }) => {
          const isPending = status === "pending";
          return (
            <button
              className={`px-4 sm:px-6 py-3 font-semibold uppercase tracking-widest transition-all w-full font-(family-name:--font-clash) text-sm sm:text-base ${
                isPending || isDisabled
                  ? "opacity-50 cursor-not-allowed"
                  : "hover:opacity-80"
              }`}
              style={{
                backgroundColor: "#FFFFFF",
                color: "#011623",
                border: "none",
                borderRadius: "0",
              }}
              onClick={onSubmit}
              disabled={isPending || isDisabled}
            >
              {isPending && (
                <span className="inline-block w-4 h-4 border-2 border-fhenix-dark border-t-transparent rounded-full animate-spin mr-2"></span>
              )}
              Increment
            </button>
          );
        }}
      />
    </Transaction>
  );
};

/**
 * DecrementButton Component
 *
 * Similar to IncrementButton, this demonstrates another operation
 * that can be performed on encrypted data without decryption.
 * The smart contract handles the decrement operation while maintaining
 * the privacy of the actual value.
 */
const DecrementButton = ({
  onSuccess,
}: {
  onSuccess: (message: string) => void;
}) => {
  const handleOnStatus = useCallback(
    (status: LifecycleStatus) => {
      console.log("Decrement transaction status:", status);
      if (status.statusName === "success") {
        console.log(" Decrement transaction successful");
        onSuccess(" Counter decremented successfully!");
      }
    },
    [onSuccess]
  );

  const calls: ContractFunctionParameters[] = [
    {
      address: CONTRACT_ADDRESS as `0x${string}`,
      abi: CONTRACT_ABI as ContractFunctionParameters["abi"],
      functionName: "decrement",
      args: [],
    },
  ];

  return (
    <Transaction
      calls={calls}
      onStatus={handleOnStatus}
      className="flex-1"
      resetAfter={2000}
    >
      <TransactionButton
        render={({ status, onSubmit, isDisabled }) => {
          const isPending = status === "pending";
          return (
            <button
              className={`px-4 sm:px-6 py-3 font-semibold uppercase tracking-widest transition-all w-full font-(family-name:--font-clash) text-sm sm:text-base ${
                isPending || isDisabled
                  ? "opacity-50 cursor-not-allowed"
                  : "hover:opacity-80"
              }`}
              style={{
                backgroundColor: "#FFFFFF",
                color: "#011623",
                border: "none",
                borderRadius: "0",
              }}
              onClick={onSubmit}
              disabled={isPending || isDisabled}
            >
              {isPending && (
                <span className="inline-block w-4 h-4 border-2 border-fhenix-dark border-t-transparent rounded-full animate-spin mr-2"></span>
              )}
              Decrement
            </button>
          );
        }}
      />
    </Transaction>
  );
};

/**
 * EncryptedCounterDisplay Component
 *
 * A reusable component that handles reading and displaying encrypted counter values.
 * This component demonstrates:
 * 1. How to read encrypted data from a smart contract
 * 2. How to display encrypted values using the EncryptedValue component
 * 3. The pattern for handling encrypted data in the UI
 *
 * @returns A component that displays the current encrypted counter value
 */
const EncryptedCounterDisplay = ({
  count,
  resetKey,
}: {
  count: bigint | undefined;
  resetKey: number;
}) => {
  const [showTooltip, setShowTooltip] = useState(false);

  return (
    <div className="w-full">
      <div className="flex items-center justify-center gap-2 mb-2">
        <p className="text-xs sm:text-sm text-white font-(family-name:--font-clash)">
          Counter Value:
        </p>
        <div
          className="relative"
          onMouseEnter={() => setShowTooltip(true)}
          onMouseLeave={() => setShowTooltip(false)}
          onClick={() => setShowTooltip(!showTooltip)}
          onTouchStart={() => setShowTooltip(!showTooltip)}
        >
          <InfoIcon className="w-3 h-3 sm:w-4 sm:h-4 text-fhenix-cyan cursor-help" />
          {showTooltip && (
            <div
              className="absolute bottom-full left-0 mb-2 px-3 py-2 text-xs text-white bg-gray-900 rounded whitespace-nowrap z-10 font-(family-name:--font-clash)"
              style={{
                boxShadow: "0 2px 8px rgba(0,0,0,0.3)",
              }}
            >
              This value is decrypted locally, only you can see it.
              <div
                className="absolute top-full left-4 w-0 h-0"
                style={{
                  borderLeft: "6px solid transparent",
                  borderRight: "6px solid transparent",
                  borderTop: "6px solid #111827",
                }}
              />
            </div>
          )}
        </div>
      </div>
      <div className="flex flex-row w-full gap-3">
        <EncryptedValue
          key={resetKey}
          fheType={FheTypes.Uint32}
          ctHash={count as bigint | undefined}
        />
      </div>
    </div>
  );
};
