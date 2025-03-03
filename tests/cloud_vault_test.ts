import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that providers can register with stake",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const provider1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'register-provider', [
        types.uint(200), // price per GB
        types.uint(1000) // available space
      ], provider1.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), true);
    
    let provider = chain.callReadOnlyFn(
      'cloud_vault',
      'get-provider-details',
      [types.principal(provider1.address)],
      deployer.address
    );
    
    let providerData = provider.result.expectSome();
    assertEquals(providerData.stake, types.uint(1000000));
    assertEquals(providerData.available_space, types.uint(1000));
  }
});

Clarinet.test({
  name: "Test payment and withdrawal functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const provider = accounts.get('wallet_1')!;
    const client = accounts.get('wallet_2')!;
    
    // Register provider
    let block1 = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'register-provider', [
        types.uint(200),
        types.uint(1000)
      ], provider.address)
    ]);
    
    // Make payment
    let block2 = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'make-payment', [
        types.uint(1),
        types.uint(200)
      ], client.address)
    ]);
    
    // Test withdrawal
    let block3 = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'withdraw-earnings', 
        [], provider.address)
    ]);
    
    assertEquals(block3.receipts[0].result.expectOk(), types.uint(200));
  }
});

Clarinet.test({
  name: "Test request cancellation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const client = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'cancel-request', [
        types.uint(1)
      ], client.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), true);
  }
});
