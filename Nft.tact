import "@stdlib/deploy";

// Messages for NFT interaction
message(0x5fcc3d14) NFTTransfer {
    queryId: Int as uint64;
    newOwner: Address; // Address of the new owner of the NFT item.
    responseDestination: Address?; // Address to send a response confirming a successful transfer and the remaining incoming message coins.
    customPayload: Cell? = null; // Optional custom data. In most cases, this should be null.
    forwardAmount: Int as coins; // The amount of nanotons to be sent to the new owner.
    forwardPayload: Slice as remaining; // Optional custom data that should be sent to the new owner.
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

// Struct for NFT data (answer of get function)
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

    init(id: Int, collection: Address, ownerAdress: Address, content: Cell, Royality_Params: Cell) {
        self.id = id;
        self.collection = collection;
        self.ownerAdress = ownerAdress;
        self.content = content;
        self.Royality_Params = Royality_Params;
    }

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

    receive(msg: NFTTransfer) {
        let ctx: Context = context();
        let msgValue: Int = ctx.value;
        
        throwUnless(1024, sender() == self.ownerAdress);
        self.ownerAdress = msg.newOwner;

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

        msgValue = msgValue - ctx.readForwardFee();

        if (msg.responseDestination != null) {
            send(SendParameters {
                to: msg.responseDestination!!,
                value: msgValue - msg.forwardAmount,
                mode: SendPayGasSeparately,
                bounce: true,
                body: Excessvalue { query_id: msg.queryId }.toCell()
            });
        }
    }

    // Get function necessary for NFTs
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
