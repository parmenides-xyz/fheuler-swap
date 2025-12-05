"use client";

import { useEffect } from "react";
import {
  Name,
  Identity,
  Address,
  Avatar,
  EthBalance,
} from "@coinbase/onchainkit/identity";
import {
  ConnectWallet,
  Wallet,
  WalletDropdown,
  WalletDropdownDisconnect,
} from "@coinbase/onchainkit/wallet";
import { useAccount, useSwitchChain } from "wagmi";
import { baseSepolia } from "wagmi/chains";

export function ConnectWalletButton() {
  const { isConnected, chainId } = useAccount();
  const { switchChain } = useSwitchChain();

  // Automatically switch to Base Sepolia if connected to wrong chain
  useEffect(() => {
    if (isConnected && chainId !== baseSepolia.id) {
      switchChain?.({ chainId: baseSepolia.id });
    }
  }, [isConnected, chainId, switchChain]);

  return (
    <Wallet>
      <ConnectWallet />
      <WalletDropdown>
        <Identity hasCopyAddressOnClick>
          <Avatar />
          <Name />
          <Address />
          <EthBalance />
        </Identity>
        <WalletDropdownDisconnect />
      </WalletDropdown>
    </Wallet>
  );
}
