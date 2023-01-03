package db

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	ethTypes "github.com/ethereum/go-ethereum/core/types"
	"github.com/synapsecns/sanguine/agents/types"
)

// TxQueueDB contains an interface for storing transactions currently being processed.
//
//go:generate go run github.com/vektra/mockery/v2 --name TxQueueDB --output ./mocks --case=underscore
type TxQueueDB interface {
	// StoreRawTx stores a raw transaction
	StoreRawTx(ctx context.Context, tx *ethTypes.Transaction, chainID *big.Int, from common.Address) error
	// StoreProcessedTx stores a tx that has already been processed
	StoreProcessedTx(ctx context.Context, tx *ethTypes.Transaction) error
	// GetNonceForChainID gets the latest nonce for a sender
	GetNonceForChainID(ctx context.Context, fromAddress common.Address, chainID *big.Int) (nonce uint64, err error)
}

// MessageDB stores messages.
// nolint
// TODO (joe): This needs to be refactored after we do the GlobalRegistry stuff
type MessageDB interface {
	// RetrieveLatestCommittedMessageNonce gets the latest nonce of a committed message
	// returns ErrNoNonceForDomain if no nonce exists
	RetrieveLatestCommittedMessageNonce(ctx context.Context, domainID uint32) (nonce uint32, err error)
	// StoreMessageLatestBlockEnd stores the latest block end
	StoreMessageLatestBlockEnd(ctx context.Context, domainID uint32, blockNumber uint32) error
	// GetMessageLatestBlockEnd gets the message latest block
	// returns ErrNoStoredBlockForChain when not present
	GetMessageLatestBlockEnd(ctx context.Context, domainID uint32) (height uint32, err error)
	// StoreCommittedMessage stores a raw committed message
	StoreCommittedMessage(ctx context.Context, domainID uint32, message types.CommittedMessage) error
	// StoreSignedAttestations stores a signed attestation
	StoreSignedAttestations(ctx context.Context, attestation types.SignedAttestation) error
	// RetrieveSignedAttestationByNonce retrieves a signed attestation by nonce
	RetrieveSignedAttestationByNonce(ctx context.Context, domainID, nonce uint32) (attestation types.SignedAttestation, err error)
}

// MonitorDB stores event data for monitoring.
type MonitorDB interface {
	// StoreDispatchMessage stores a dispatch message
	StoreDispatchMessage(ctx context.Context, message types.Message) error
	// StoreAcceptedAttestation stores an accepted attestation
	StoreAcceptedAttestation(ctx context.Context, attestation types.Attestation) error
	// GetDelinquentMessage gets messages that were sent, but never received
	GetDelinquentMessages(ctx context.Context, destinationDomain uint32) ([]types.Message, error)
}

// InProgressAttestationDB stores in-progress attesations.
// nolint
type InProgressAttestationDB interface {
	// RetrieveLatestCachedNonce gets the latest nonce cached for a particular origin-destination pair
	// returns ErrNoNonceForDomain if no nonce exists.
	RetrieveLatestCachedNonce(ctx context.Context, originID, destinationID uint32) (nonce uint32, err error)
	// StoreNewInProgressAttestation stores a in-progress attestation only if it hasn't already been stored
	StoreNewInProgressAttestation(ctx context.Context, attestation types.Attestation, originDispathBlockNumber uint64) error
	// UpdateNotarySignature sets the notary signature of the in-progress Attestation.
	UpdateNotarySignature(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// UpdateNotarySubmittedToAttestationCollectorTime sets the time the attestation was sent to Attestation Collector by the Notary.
	UpdateNotarySubmittedToAttestationCollectorTime(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// ReUpdateNotarySubmittedToAttestationCollectorTime sets the time the attestation was sent to Attestation Collector by the Notary when resubmitting.
	ReUpdateNotarySubmittedToAttestationCollectorTime(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// MarkNotaryConfirmedOnAttestationCollector confirms that the notary posted the signed attestation on the Attestation Collector.
	MarkNotaryConfirmedOnAttestationCollector(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// RetrieveInProgressAttestation retrieves an in-progress attestation by <origin, destination, nonce>.
	RetrieveInProgressAttestation(ctx context.Context, originID, destinationID, nonce uint32) (inProgressAttestation types.InProgressAttestation, err error)
	// RetrieveOldestUnsignedInProgressAttestation retrieves the oldest in-progress attestation that has not yet been signed.
	RetrieveOldestUnsignedInProgressAttestation(ctx context.Context, originID, destinationID uint32) (inProgressAttestation types.InProgressAttestation, err error)
	// RetrieveOldestUnsubmittedSignedInProgressAttestation retrieves the oldest in-progress attestation that has been signed but not yet submitted.
	RetrieveOldestUnsubmittedSignedInProgressAttestation(ctx context.Context, originID, destinationID uint32) (inProgressAttestation types.InProgressAttestation, err error)
	// RetrieveOldestUnconfirmedSubmittedInProgressAttestation retrieves the oldest in-progress attestation that has been signed and submitted but not yet confirmed on the AttestationCollector.
	RetrieveOldestUnconfirmedSubmittedInProgressAttestation(ctx context.Context, originID, destinationID uint32) (inProgressAttestation types.InProgressAttestation, err error)
	// RetrieveNewestConfirmedInProgressAttestation retrieves the newest in-progress attestation that has been confirmed on the AttestationCollector.
	RetrieveNewestConfirmedInProgressAttestation(ctx context.Context, originID, destinationID uint32) (inProgressAttestation types.InProgressAttestation, err error)
	// RetrieveOldestGuardUnsignedAndUnverifiedInProgressAttestation retrieves the oldest in-progress attestation that has been signed by a notary but not a guard
	// and it has not been verified on the origin.
	RetrieveOldestGuardUnsignedAndUnverifiedInProgressAttestation(ctx context.Context, originID, destinationID uint32) (inProgressAttestation types.InProgressAttestation, err error)
	// RetrieveOldestGuardUnsignedAndVerifiedInProgressAttestation retrieves the oldest in-progress attestation that has been signed by a notary but not a guard
	// but it has  been verified on the origin.
	RetrieveOldestGuardUnsignedAndVerifiedInProgressAttestation(ctx context.Context, originID, destinationID uint32) (inProgressAttestation types.InProgressAttestation, err error)
	// StoreExistingSignedInProgressAttestation stores a signed in-progress attestation only if it hasn't already been stored
	StoreExistingSignedInProgressAttestation(ctx context.Context, signedAttestation types.SignedAttestation) error
	// MarkVerifiedOnOrigin marks the attestation as having been verified on origin.
	MarkVerifiedOnOrigin(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// UpdateGuardSignature sets the guard signature of the in-progress Attestation.
	UpdateGuardSignature(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// RetrieveOldestGuardUnsubmittedSignedInProgressAttestation retrieves the oldest in-progress attestation that has been signed by the notary and guard but not yet submitted.
	RetrieveOldestGuardUnsubmittedSignedInProgressAttestation(ctx context.Context, originID, destinationID uint32) (inProgressAttestation types.InProgressAttestation, err error)
	// UpdateGuardSubmittedToAttestationCollectorTime sets the time the attestation was sent to Attestation Collector by the Guard.
	UpdateGuardSubmittedToAttestationCollectorTime(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// ReUpdateGuardSubmittedToAttestationCollectorTime sets the time the attestation was sent to Attestation Collector by the Guard when resubmitting.
	ReUpdateGuardSubmittedToAttestationCollectorTime(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// RetrieveOldestGuardSubmittedToCollectorUnconfirmed retrieves the oldest in-progress attestation that has been signed by both the guard and notary and submitted to the attestation collector,
	// but not yet confirmed.
	RetrieveOldestGuardSubmittedToCollectorUnconfirmed(ctx context.Context, originID, destinationID uint32) (_ types.InProgressAttestation, err error)
	// MarkGuardConfirmedOnAttestationCollector confirms that the guard posted the signed attestation on the Attestation Collector.
	MarkGuardConfirmedOnAttestationCollector(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// RetrieveOldestGuardConfirmedOnCollector retrieves the oldest in-progress attestation that has been signed by both the guard and notary and submitted to the attestation collector,
	// and confirmed on the Attestation Collector.
	RetrieveOldestGuardConfirmedOnCollector(ctx context.Context, originID, destinationID uint32) (_ types.InProgressAttestation, err error)
	// UpdateSubmittedToDestinationTime sets the time the attestation was sent to the Destination.
	UpdateSubmittedToDestinationTime(ctx context.Context, inProgressAttestation types.InProgressAttestation) error
	// RetrieveOldestSubmittedToDestinationUnconfirmed retrieves the oldest in-progress attestation that has been signed by both the guard and notary and submitted to the attestation collector and destination,
	// but not yet confirmed on the destination.
	RetrieveOldestSubmittedToDestinationUnconfirmed(ctx context.Context, originID, destinationID uint32) (_ types.InProgressAttestation, err error)
}

// SynapseDB combines db types.
type SynapseDB interface {
	MessageDB
	TxQueueDB
	MonitorDB
	InProgressAttestationDB
}
