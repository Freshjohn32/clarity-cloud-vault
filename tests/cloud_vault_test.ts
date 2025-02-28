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
    
    // Verify provider details including stake
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
  name: "Test contract pause functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Pause contract
    let block1 = chain.mineBlock([
      Tx.contractCall('cloud_vault', 'toggle-contract-pause', 
        [], deployer.address)
    ]);
    
    assertEquals(block1.receipts[0].result.expectOk(), true);
    
    // Verify contract is paused
    let status = chain.callReadOnlyFn(
      'cloud_vault',
      'get-contract-status',
      [],
      deployer.address
    );
    
    assertEquals(status.result.expectOk(), true);
  }
});
