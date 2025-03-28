import "@stdlib/deploy";

// Minimum TON amount required for storage
const min_ton_for_storage: Int = ton("0.05");

// Messages for NFT interaction
message(0x5fcc3d14) NFTTransfer {
    queryId: Int as uint64;
    newOwner: Address; // Address of the new NFT owner
    responseDestination: Address?; // Address to send response confirmation
    customPayload: Cell? = null; // Optional custom data
    forwardAmount: Int as coins; // Amount of nanotons to be sent to new owner
    forwardPayload: Slice as remaining; // Custom data to be sent to new owner
}

message(0xd53276db) Excessvalue {
    query_id: Int as uint64;
}

message(0x05138d91) NFTOwnershipAssigned {
    queryId: Int as uint64;
    previousOwner: Address;
    forwardPayload: Slice as remaining;
}

message(0x2fcb26a2) GetStaticData {
    query_id: Int as uint64;
}

message(0x693d3950) GetRoyalityParams {
    queryId: Int as uint64;
}

message(0x8b771735) SendRoyalityParams {
    queryId: Int as uint64;
    data: Cell;
}

message(0x8b771735) ReportStaticData {
    queryId: Int as uint64;
    id: Int;
    collection: Address;
}

// Struct for NFT data (response to get function)
struct NftData {
    bool: Bool;
    id: Int;
    collection: Address;
    owner: Address;
    content: Cell;
}

contract NFT with Deployable {
    id: Int as uint64;
    collection: Address;
    ownerAdress: Address;
    content: Cell;
    Royality_Params: Cell;

    // Initialize NFT contract with parameters
    init(id: Int, collection: Address, ownerAdress: Address, content: Cell, Royality_Params: Cell) {
        self.id = id;
        self.collection = collection;
        self.ownerAdress = ownerAdress;
        self.content = content;
        self.Royality_Params = Royality_Params;
    }

    // Handle GetStaticData message
    receive(msg: GetStaticData) {
        let ctx: Context = context();
        send(SendParameters {
            to: ctx.sender,
            value: 0,
            mode: 64,
            bounce: true,
            body: ReportStaticData {
                queryId: msg.query_id,
                id: self.id,
                collection: self.collection
            }.toCell()
        });
    }

    // Handle GetRoyalityParams message
    receive(msg: GetRoyalityParams) {
        let ctx: Context = context();
        send(SendParameters {
            to: ctx.sender,
            value: 0,
            mode: 64,
            bounce: true,
            body: SendRoyalityParams {
                queryId: msg.queryId,
                data: self.Royality_Params
            }.toCell()
        });
    }

    // Handle NFTTransfer message
    receive(msg: NFTTransfer) {
        throwUnless(1024, sender() == self.ownerAdress);
        let ctx: Context = context();
        
        // Calculate remaining balance after required deductions
        let msgvalue = myBalance() - min_ton_for_storage - ctx.readForwardFee() - msg.forwardAmount;
        throwUnless(402, msgvalue >= 0);

        // Transfer ownership to new owner
        self.ownerAdress = msg.newOwner;

        // Forward nanotons to new owner if specified
        if (msg.forwardAmount > 0) {
            send(SendParameters {
                to: msg.newOwner,
                value: msg.forwardAmount,
                mode: SendPayGasSeparately,
                bounce: true,
                body: NFTOwnershipAssigned {
                    queryId: msg.queryId,
                    previousOwner: ctx.sender,
                    forwardPayload: msg.forwardPayload
                }.toCell()
            });
        }

        // Send excess value back to response destination if applicable
        if (msg.responseDestination != null) {
            send(SendParameters {
                to: msg.responseDestination!!,
                value: msgvalue,
                mode: SendPayGasSeparately,
                bounce: true,
                body: Excessvalue { query_id: msg.queryId }.toCell()
            });
        }
    }

    // Getter function for NFT data
    get fun getNftData(): NftData {
        return NftData {
            bool: true,
            id: self.id,
            collection: self.collection,
            owner: self.ownerAdress,
            content: self.content
        };
    }
}
