"use client";
import { useEffect } from "react";
import { useMiniKit } from "@coinbase/onchainkit/minikit";
import { ConnectWalletButton } from "../components/ConnectWalletButton";
import { Footer } from "../components/Footer";
import Image from "next/image";
import { FHECounter } from "../components/FHECounter";
import { usePermit } from "../hooks/usePermit";
import { useCofheStore } from "../store/cofheStore";
import { useAccount } from "wagmi";
import { useCofhe } from "../hooks/useCofhe";

export default function Home() {
  const { isFrameReady, setFrameReady, context } = useMiniKit();
  const { address: _address, isConnected } = useAccount();

  const {
    hasValidPermit,
    isGeneratingPermit,
    error: _permitError,
    generatePermit,
    removePermit,
  } = usePermit();
  const { isInitialized: isCofheInitialized } = useCofheStore();
  const { isInitializing, isInitialized: _isInitialized } = useCofhe();

  const handleGeneratePermit = async () => {
    const result = await generatePermit();
    if (!result.success) {
      console.error("Failed to generate permit:", result.error);
    }
  };

  const handleRemovePermit = async () => {
    const success = await removePermit();
    if (success) {
      console.log("Permit removed successfully");
    }
  };

  // If you need to verify the user's identity, you can use the useQuickAuth hook.
  // This hook will verify the user's signature and return the user's FID. You can update
  // this to meet your needs. See the /app/api/auth/route.ts file for more details.
  // Note: If you don't need to verify the user's identity, you can get their FID and other user data
  // via `context.user.fid`.
  // const { data, isLoading, error } = useQuickAuth<{
  //   userFid: string;
  // }>("/api/auth");

  // Initialize the  miniapp
  useEffect(() => {
    if (!isFrameReady) {
      setFrameReady();
    }
  }, [setFrameReady, isFrameReady]);

  return (
    <div className="min-h-screen flex flex-col bg-linear-to-b from-fhenix-dark via-slate-950 to-fhenix-dark">
      <div className="flex-1 flex items-center justify-center p-6">
        <div className="w-full max-w-2xl">
          <div className="space-y-8 text-center">
            <div className="relative z-10 space-y-8">
              <div className="flex flex-col items-center justify-center gap-10">
                <Image
                  src="/fhenix_logo_dark.svg"
                  alt="Fhenix"
                  width={400}
                  height={100}
                  className="w-80 md:w-96"
                />
                <h1 className="text-2xl md:text-4xl font-semibold tracking-tight font-(family-name:--font-clash)">
                  <span style={{ color: "#0AD9DC" }}>MINIAPP</span>{" "}
                  <span className="text-white">DEMO</span>
                </h1>
              </div>

              <p className="text-lg md:text-xl text-white leading-relaxed max-w-xl mx-auto font-(family-name:--font-geist)">
                Hey {context?.user?.displayName || "there"}! Interact with
                encrypted data on-chain without ever revealing it.
              </p>

              <div className="pt-4 flex justify-center">
                <ConnectWalletButton />
              </div>

              <span className="text-sm font-medium text-white">
                {isInitializing && "Initializing CoFHE..."}
              </span>
              {isCofheInitialized && !hasValidPermit && (
                <button
                  onClick={handleGeneratePermit}
                  disabled={hasValidPermit || isGeneratingPermit}
                  className="mt-4 mb-2 inline-flex items-center gap-2 px-6 py-3 uppercase tracking-widest transition-all duration-200 hover:opacity-80 disabled:opacity-50 disabled:cursor-not-allowed font-semibold font-(family-name:--font-clash)"
                  style={{
                    backgroundColor: "#FFFFFF",
                    color: "#011623",
                    border: "none",
                    borderRadius: "0",
                  }}
                >
                  {isGeneratingPermit ? (
                    <>
                      <div className="animate-spin rounded-full h-3 w-3 border-2 border-fhenix-dark border-t-transparent"></div>
                      <span>Generating...</span>
                    </>
                  ) : (
                    <>
                      <span>Generate Permit</span>
                    </>
                  )}
                </button>
              )}
              {isConnected && isCofheInitialized && hasValidPermit && (
                <FHECounter />
              )}

              {/* Remove Permit Button */}
              {isConnected && isCofheInitialized && hasValidPermit && (
                <button
                  onClick={handleRemovePermit}
                  className="mt-4 mb-2 inline-flex items-center gap-2 px-6 py-3 uppercase tracking-widest transition-all duration-200 hover:opacity-80 font-semibold font-(family-name:--font-clash)"
                  style={{
                    backgroundColor: "#FFFFFF",
                    color: "#011623",
                    border: "none",
                    borderRadius: "0",
                  }}
                >
                  <span>🗑️ Revoke Permit</span>
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
      <Footer />
    </div>
  );
}
