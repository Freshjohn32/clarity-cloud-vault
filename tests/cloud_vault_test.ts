import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that providers can register",
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
    
    // Verify provider details
    let provider = chain.callReadOnlyFn(
      'cloud_vault',
      'get-provider-details',
      [types.principal(provider1.address)],
      deployer.address
    );
    
    assertEquals(provider.result.expectSome().available_space, types.uint(1000));
  }
});

Clarinet.test({
  name: "Test storage request and acceptance flow",
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
    
    // Request storage
    let block2 = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'request-storage', [
        types.principal(provider.address),
        types.uint(100)
      ], client.address)
    ]);
    
    const requestId = block2.receipts[0].result.expectOk();
    
    // Accept request
    let block3 = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'accept-request', [
        requestId
      ], provider.address)
    ]);
    
    assertEquals(block3.receipts[0].result.expectOk(), true);
    
    // Verify updated provider space
    let provider_details = chain.callReadOnlyFn(
      'cloud_vault',
      'get-provider-details',
      [types.principal(provider.address)],
      provider.address
    );
    
    assertEquals(
      provider_details.result.expectSome().available_space,
      types.uint(900)
    );
  }
});

Clarinet.test({
  name: "Ensure unauthorized operations fail",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const attacker = accounts.get('wallet_3')!;
    
    // Try to accept non-existent request
    let block = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'accept-request', [
        types.uint(999)
      ], attacker.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectErr(), types.uint(101));
  }
});