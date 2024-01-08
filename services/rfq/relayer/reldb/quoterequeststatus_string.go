// Code generated by "stringer -type=QuoteRequestStatus"; DO NOT EDIT.

package reldb

import "strconv"

func _() {
	// An "invalid array index" compiler error signifies that the constant values have changed.
	// Re-run the stringer command to generate them again.
	var x [1]struct{}
	_ = x[Seen-1]
	_ = x[NotEnoughInventory-2]
	_ = x[DeadlineExceeded-3]
	_ = x[WillNotProcess-4]
	_ = x[CommittedPending-5]
	_ = x[CommittedConfirmed-6]
	_ = x[RelayStarted-7]
	_ = x[RelayCompleted-8]
	_ = x[ProvePosting-9]
	_ = x[ProvePosted-10]
	_ = x[ClaimPending-11]
	_ = x[ClaimCompleted-12]
}

const _QuoteRequestStatus_name = "SeenNotEnoughInventoryDeadlineExceededWillNotProcessCommittedPendingCommittedConfirmedRelayStartedRelayCompletedProvePostingProvePostedClaimPendingClaimCompleted"

var _QuoteRequestStatus_index = [...]uint8{0, 4, 22, 38, 52, 68, 86, 98, 112, 124, 135, 147, 161}

func (i QuoteRequestStatus) String() string {
	i -= 1
	if i >= QuoteRequestStatus(len(_QuoteRequestStatus_index)-1) {
		return "QuoteRequestStatus(" + strconv.FormatInt(int64(i+1), 10) + ")"
	}
	return _QuoteRequestStatus_name[_QuoteRequestStatus_index[i]:_QuoteRequestStatus_index[i+1]]
}
