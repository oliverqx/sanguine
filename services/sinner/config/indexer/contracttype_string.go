// Code generated by "stringer -type=ContractType -linecomment"; DO NOT EDIT.

package indexerconfig

import "strconv"

func _() {
	// An "invalid array index" compiler error signifies that the constant values have changed.
	// Re-run the stringer command to generate them again.
	var x [1]struct{}
	_ = x[OriginType-0]
	_ = x[ExecutionHubType-1]
	_ = x[UnknownType-2]
}

const _ContractType_name = "originexecution_hubunknown"

var _ContractType_index = [...]uint8{0, 6, 19, 26}

func (i ContractType) String() string {
	if i < 0 || i >= ContractType(len(_ContractType_index)-1) {
		return "ContractType(" + strconv.FormatInt(int64(i), 10) + ")"
	}
	return _ContractType_name[_ContractType_index[i]:_ContractType_index[i+1]]
}