import type { Abi } from 'viem';

declare module "*.json" {
    const value: Abi;
    export default value;
}
