import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Test campaign creation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const deadline = chain.blockHeight + 100;
    
    let block = chain.mineBlock([
      Tx.contractCall('pitch-fund', 'create-campaign', [
        types.ascii("Test Campaign"),
        types.ascii("Test Description"),
        types.uint(1000000),
        types.uint(deadline)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1);
    
    const response = chain.callReadOnlyFn(
      'pitch-fund',
      'get-campaign',
      [types.uint(1)],
      deployer.address
    );
    response.result.expectOk().expectTuple();
  }
});

Clarinet.test({
  name: "Test contribution flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 100;
    
    // Create campaign
    let block = chain.mineBlock([
      Tx.contractCall('pitch-fund', 'create-campaign', [
        types.ascii("Test Campaign"),
        types.ascii("Test Description"),
        types.uint(1000000),
        types.uint(deadline)
      ], deployer.address)
    ]);
    
    // Contribute to campaign
    block = chain.mineBlock([
      Tx.contractCall('pitch-fund', 'contribute', [
        types.uint(1),
        types.uint(500000)
      ], wallet1.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Check contribution
    const response = chain.callReadOnlyFn(
      'pitch-fund',
      'get-contribution',
      [types.uint(1), types.principal(wallet1.address)],
      wallet1.address
    );
    response.result.expectOk().expectUint(500000);
  }
});

Clarinet.test({
  name: "Test withdrawal flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const deadline = chain.blockHeight + 100;
    
    // Create and fund campaign
    let block = chain.mineBlock([
      Tx.contractCall('pitch-fund', 'create-campaign', [
        types.ascii("Test Campaign"),
        types.ascii("Test Description"),
        types.uint(1000000),
        types.uint(deadline)
      ], deployer.address),
      Tx.contractCall('pitch-fund', 'contribute', [
        types.uint(1),
        types.uint(1000000)
      ], wallet1.address)
    ]);
    
    // Test withdrawal
    block = chain.mineBlock([
      Tx.contractCall('pitch-fund', 'withdraw-funds', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});
