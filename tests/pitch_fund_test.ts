import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous test cases remain unchanged...]

Clarinet.test({
  name: "Test refund flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 10;
    
    // Create and contribute to campaign
    let block = chain.mineBlock([
      Tx.contractCall('pitch-fund', 'create-campaign', [
        types.ascii("Test Campaign"),
        types.ascii("Test Description"),
        types.uint(1000000),
        types.uint(deadline)
      ], deployer.address),
      Tx.contractCall('pitch-fund', 'contribute', [
        types.uint(1),
        types.uint(500000)
      ], wallet1.address)
    ]);
    
    // Advance blockchain past deadline
    chain.mineEmptyBlockUntil(deadline + 1);
    
    // Test refund
    block = chain.mineBlock([
      Tx.contractCall('pitch-fund', 'claim-refund', [
        types.uint(1)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});
