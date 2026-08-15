// AI SLOP
// https://www.gregorygaines.com/blog/decoding-the-arm7tdmi-instruction-set-game-boy-advance/

#pragma once

#include <cstdint>
#include <string_view>

enum class ArmInstruction {
    BranchAndBranchExchange,
    BlockDataTransfer,
    BranchAndBranchWithLink,
    SoftwareInterrupt,
    Undefined,
    SingleDataTransfer,
    SingleDataSwap,
    Multiply,
    HalfwordDataTransferRegister,
    HalfwordDataTransferImmediate,
    PSRTransferMRS,
    PSRTransferMSR,
    DataProcessing,
    Unimplemented
};

enum class ThumbInstruction {
    SoftwareInterrupt,
    UnconditionalBranch,
    ConditionalBranch,
    MultipleLoadStore,
    LongBranchWithLink,
    AddOffsetToStackPointer,
    PushPopRegisters,
    LoadStoreHalfword,
    SPRelativeLoadStore,
    LoadAddress,
    LoadStoreWithImmediateOffset,
    LoadStoreWithRegisterOffset,
    LoadStoreSignExtendedByteHalfword,
    PCRelativeLoad,
    HiRegisterOperationsBranchExchange,
    ALUOperations,
    MoveCompareAddSubtractImmediate,
    AddSubtract,
    MoveShiftedRegister,
    Unimplemented
};

// ---------------- ARM helpers ----------------

constexpr bool IsBranchAndBranchExchange(uint32_t opcode) {
    constexpr uint32_t format = 0b00000001001011111111111100010000u;
    constexpr uint32_t mask = 0b00001111111111111111111111110000u;
    return (opcode & mask) == format;
}

constexpr bool IsBlockDataTransfer(uint32_t opcode) {
    constexpr uint32_t format = 0b00001000000000000000000000000000u;
    constexpr uint32_t mask = 0b00001110000000000000000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsBranchAndBranchWithLink(uint32_t opcode) {
    constexpr uint32_t branchFormat = 0b00001010000000000000000000000000u;
    constexpr uint32_t branchWithLinkFormat = 0b00001011000000000000000000000000u;
    constexpr uint32_t mask = 0b00001111000000000000000000000000u;
    const uint32_t extracted = opcode & mask;
    return extracted == branchFormat || extracted == branchWithLinkFormat;
}

constexpr bool IsSoftwareInterrupt(uint32_t opcode) {
    constexpr uint32_t format = 0b00001111000000000000000000000000u;
    constexpr uint32_t mask = 0b00001111000000000000000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsUndefined(uint32_t opcode) {
    constexpr uint32_t format = 0b00000110000000000000000000010000u;
    constexpr uint32_t mask = 0b00001110000000000000000000010000u;
    return (opcode & mask) == format;
}

constexpr bool IsSingleDataTransfer(uint32_t opcode) {
    constexpr uint32_t format = 0b00000100000000000000000000000000u;
    constexpr uint32_t mask = 0b00001100000000000000000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsSingleDataSwap(uint32_t opcode) {
    constexpr uint32_t format = 0b00000001000000000000000010010000u;
    constexpr uint32_t mask = 0b00001111100000000000111111110000u;
    return (opcode & mask) == format;
}

constexpr bool IsMultiply(uint32_t opcode) {
    constexpr uint32_t multiplyFormat = 0b00000000000000000000000010010000u;
    constexpr uint32_t multiplyLongFormat = 0b00000000100000000000000010010000u;
    constexpr uint32_t mask = 0b00001111100000000000000011110000u;
    const uint32_t extracted = opcode & mask;
    return extracted == multiplyFormat || extracted == multiplyLongFormat;
}

constexpr bool IsHalfwordDataTransferRegister(uint32_t opcode) {
    constexpr uint32_t format = 0b00000000000000000000000010010000u;
    constexpr uint32_t mask = 0b00001110010000000000111110010000u;
    return (opcode & mask) == format;
}

constexpr bool IsHalfwordDataTransferImmediate(uint32_t opcode) {
    constexpr uint32_t format = 0b00000000010000000000000010010000u;
    constexpr uint32_t mask = 0b00001110010000000000000010010000u;
    return (opcode & mask) == format;
}

constexpr bool IsPSRTransferMRS(uint32_t opcode) {
    constexpr uint32_t format = 0b00000001000011110000000000000000u;
    constexpr uint32_t mask = 0b00001111101111110000000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsPSRTransferMSR(uint32_t opcode) {
    constexpr uint32_t format = 0b00000001001000001111000000000000u;
    constexpr uint32_t mask = 0b00001101101100001111000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsDataProcessing(uint32_t opcode) {
    constexpr uint32_t format = 0b00000000000000000000000000000000u;
    constexpr uint32_t mask = 0b00001100000000000000000000000000u;
    return (opcode & mask) == format;
}

constexpr ArmInstruction DecodeARMInstruction(uint32_t opcode) {
    if (IsBranchAndBranchExchange(opcode))
        return ArmInstruction::BranchAndBranchExchange;
    if (IsBlockDataTransfer(opcode))
        return ArmInstruction::BlockDataTransfer;
    if (IsBranchAndBranchWithLink(opcode))
        return ArmInstruction::BranchAndBranchWithLink;
    if (IsSoftwareInterrupt(opcode))
        return ArmInstruction::SoftwareInterrupt;
    if (IsUndefined(opcode))
        return ArmInstruction::Undefined;
    if (IsSingleDataTransfer(opcode))
        return ArmInstruction::SingleDataTransfer;
    if (IsSingleDataSwap(opcode))
        return ArmInstruction::SingleDataSwap;
    if (IsMultiply(opcode))
        return ArmInstruction::Multiply;
    if (IsHalfwordDataTransferRegister(opcode))
        return ArmInstruction::HalfwordDataTransferRegister;
    if (IsHalfwordDataTransferImmediate(opcode))
        return ArmInstruction::HalfwordDataTransferImmediate;
    if (IsPSRTransferMRS(opcode))
        return ArmInstruction::PSRTransferMRS;
    if (IsPSRTransferMSR(opcode))
        return ArmInstruction::PSRTransferMSR;
    if (IsDataProcessing(opcode))
        return ArmInstruction::DataProcessing;
    return ArmInstruction::Unimplemented;
}

constexpr std::string_view ToString(ArmInstruction instr) {
    switch (instr) {
    case ArmInstruction::BranchAndBranchExchange:
        return "BranchAndBranchExchange";
    case ArmInstruction::BlockDataTransfer:
        return "BlockDataTransfer";
    case ArmInstruction::BranchAndBranchWithLink:
        return "BranchAndBranchWithLink";
    case ArmInstruction::SoftwareInterrupt:
        return "SoftwareInterrupt";
    case ArmInstruction::Undefined:
        return "Undefined";
    case ArmInstruction::SingleDataTransfer:
        return "SingleDataTransfer";
    case ArmInstruction::SingleDataSwap:
        return "SingleDataSwap";
    case ArmInstruction::Multiply:
        return "Multiply";
    case ArmInstruction::HalfwordDataTransferRegister:
        return "HalfwordDataTransferRegister";
    case ArmInstruction::HalfwordDataTransferImmediate:
        return "HalfwordDataTransferImmediate";
    case ArmInstruction::PSRTransferMRS:
        return "PSRTransferMRS";
    case ArmInstruction::PSRTransferMSR:
        return "PSRTransferMSR";
    case ArmInstruction::DataProcessing:
        return "DataProcessing";
    default:
        return "UnimplementedARMInstruction";
    }
}

// ---------------- THUMB helpers ----------------

constexpr bool IsTHUMBSoftwareInterrupt(uint16_t opcode) {
    constexpr uint16_t format = 0b1101111100000000u;
    constexpr uint16_t mask = 0b1111111100000000u;
    return (opcode & mask) == format;
}

constexpr bool IsUnconditionalBranch(uint16_t opcode) {
    constexpr uint16_t format = 0b1110000000000000u;
    constexpr uint16_t mask = 0b1111100000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsConditionalBranch(uint16_t opcode) {
    constexpr uint16_t format = 0b1101000000000000u;
    constexpr uint16_t mask = 0b1111000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsMultipleLoadStore(uint16_t opcode) {
    constexpr uint16_t format = 0b1100000000000000u;
    constexpr uint16_t mask = 0b1111000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsLongBranchWithLink(uint16_t opcode) {
    constexpr uint16_t format = 0b1111000000000000u;
    constexpr uint16_t mask = 0b1111000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsAddOffsetToStackPointer(uint16_t opcode) {
    constexpr uint16_t format = 0b1011000000000000u;
    constexpr uint16_t mask = 0b1111111100000000u;
    return (opcode & mask) == format;
}

constexpr bool IsPushPopRegisters(uint16_t opcode) {
    constexpr uint16_t format = 0b1011010000000000u;
    constexpr uint16_t mask = 0b1111011000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsLoadStoreHalfword(uint16_t opcode) {
    constexpr uint16_t format = 0b1000000000000000u;
    constexpr uint16_t mask = 0b1111000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsSPRelativeLoadStore(uint16_t opcode) {
    constexpr uint16_t format = 0b1001000000000000u;
    constexpr uint16_t mask = 0b1111000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsLoadAddress(uint16_t opcode) {
    constexpr uint16_t format = 0b1010000000000000u;
    constexpr uint16_t mask = 0b1111000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsLoadStoreWithImmediateOffset(uint16_t opcode) {
    constexpr uint16_t format = 0b0110000000000000u;
    constexpr uint16_t mask = 0b1110000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsLoadStoreWithRegisterOffset(uint16_t opcode) {
    constexpr uint16_t format = 0b0101000000000000u;
    constexpr uint16_t mask = 0b1111001000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsLoadStoreSignExtendedByteHalfword(uint16_t opcode) {
    constexpr uint16_t format = 0b0101001000000000u;
    constexpr uint16_t mask = 0b1111001000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsPCRelativeLoad(uint16_t opcode) {
    constexpr uint16_t format = 0b0100100000000000u;
    constexpr uint16_t mask = 0b1111100000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsHiRegisterOperationsBranchExchange(uint16_t opcode) {
    constexpr uint16_t format = 0b0100010000000000u;
    constexpr uint16_t mask = 0b1111110000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsALUOperations(uint16_t opcode) {
    constexpr uint16_t format = 0b0100000000000000u;
    constexpr uint16_t mask = 0b1111110000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsMoveCompareAddSubtractImmediate(uint16_t opcode) {
    constexpr uint16_t format = 0b0010000000000000u;
    constexpr uint16_t mask = 0b1110000000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsAddSubtract(uint16_t opcode) {
    constexpr uint16_t format = 0b0001100000000000u;
    constexpr uint16_t mask = 0b1111100000000000u;
    return (opcode & mask) == format;
}

constexpr bool IsMoveShiftedRegister(uint16_t opcode) {
    constexpr uint16_t format = 0b0000000000000000u;
    constexpr uint16_t mask = 0b1110000000000000u;
    return (opcode & mask) == format;
}

constexpr ThumbInstruction DecodeTHUMBInstruction(uint16_t opcode) {
    if (IsTHUMBSoftwareInterrupt(opcode))
        return ThumbInstruction::SoftwareInterrupt;
    if (IsUnconditionalBranch(opcode))
        return ThumbInstruction::UnconditionalBranch;
    if (IsConditionalBranch(opcode))
        return ThumbInstruction::ConditionalBranch;
    if (IsMultipleLoadStore(opcode))
        return ThumbInstruction::MultipleLoadStore;
    if (IsLongBranchWithLink(opcode))
        return ThumbInstruction::LongBranchWithLink;
    if (IsAddOffsetToStackPointer(opcode))
        return ThumbInstruction::AddOffsetToStackPointer;
    if (IsPushPopRegisters(opcode))
        return ThumbInstruction::PushPopRegisters;
    if (IsLoadStoreHalfword(opcode))
        return ThumbInstruction::LoadStoreHalfword;
    if (IsSPRelativeLoadStore(opcode))
        return ThumbInstruction::SPRelativeLoadStore;
    if (IsLoadAddress(opcode))
        return ThumbInstruction::LoadAddress;
    if (IsLoadStoreWithImmediateOffset(opcode))
        return ThumbInstruction::LoadStoreWithImmediateOffset;
    if (IsLoadStoreWithRegisterOffset(opcode))
        return ThumbInstruction::LoadStoreWithRegisterOffset;
    if (IsLoadStoreSignExtendedByteHalfword(opcode))
        return ThumbInstruction::LoadStoreSignExtendedByteHalfword;
    if (IsPCRelativeLoad(opcode))
        return ThumbInstruction::PCRelativeLoad;
    if (IsHiRegisterOperationsBranchExchange(opcode))
        return ThumbInstruction::HiRegisterOperationsBranchExchange;
    if (IsALUOperations(opcode))
        return ThumbInstruction::ALUOperations;
    if (IsMoveCompareAddSubtractImmediate(opcode))
        return ThumbInstruction::MoveCompareAddSubtractImmediate;
    if (IsAddSubtract(opcode))
        return ThumbInstruction::AddSubtract;
    if (IsMoveShiftedRegister(opcode))
        return ThumbInstruction::MoveShiftedRegister;
    return ThumbInstruction::Unimplemented;
}

constexpr std::string_view ToString(ThumbInstruction instr) {
    switch (instr) {
    case ThumbInstruction::SoftwareInterrupt:
        return "THUMBSoftwareInterrupt";
    case ThumbInstruction::UnconditionalBranch:
        return "UnconditionalBranch";
    case ThumbInstruction::ConditionalBranch:
        return "ConditionalBranch";
    case ThumbInstruction::MultipleLoadStore:
        return "MultipleLoadStore";
    case ThumbInstruction::LongBranchWithLink:
        return "LongBranchWithLink";
    case ThumbInstruction::AddOffsetToStackPointer:
        return "AddOffsetToStackPointer";
    case ThumbInstruction::PushPopRegisters:
        return "PushPopRegisters";
    case ThumbInstruction::LoadStoreHalfword:
        return "LoadStoreHalfword";
    case ThumbInstruction::SPRelativeLoadStore:
        return "SPRelativeLoadStore";
    case ThumbInstruction::LoadAddress:
        return "LoadAddress";
    case ThumbInstruction::LoadStoreWithImmediateOffset:
        return "LoadStoreWithImmediateOffset";
    case ThumbInstruction::LoadStoreWithRegisterOffset:
        return "LoadStoreWithRegisterOffset";
    case ThumbInstruction::LoadStoreSignExtendedByteHalfword:
        return "LoadStoreSignExtendedByteHalfword";
    case ThumbInstruction::PCRelativeLoad:
        return "PCRelativeLoad";
    case ThumbInstruction::HiRegisterOperationsBranchExchange:
        return "HiRegisterOperationsBranchExchange";
    case ThumbInstruction::ALUOperations:
        return "ALUOperations";
    case ThumbInstruction::MoveCompareAddSubtractImmediate:
        return "MoveCompareAddSubtractImmediate";
    case ThumbInstruction::AddSubtract:
        return "AddSubtract";
    case ThumbInstruction::MoveShiftedRegister:
        return "MoveShiftedRegister";
    default:
        return "UnimplementedTHUMBInstruction";
    }
}

enum class CpuMode {
    User,
    FIQ,
    IRQ,
    Supervisor,
    Abort,
    Undefined,
    System,
    Unknown
};

static CpuMode decode_cpu_mode(uint32_t cpsr) {
    uint32_t m = cpsr & 0x1F;

    switch (m) {
    case 0x10:
        return CpuMode::User;
    case 0x11:
        return CpuMode::FIQ;
    case 0x12:
        return CpuMode::IRQ;
    case 0x13:
        return CpuMode::Supervisor;
    case 0x17:
        return CpuMode::Abort;
    case 0x1B:
        return CpuMode::Undefined;
    case 0x1F:
        return CpuMode::System;
    default:
        return CpuMode::Unknown;
    }
}

static const char* cpu_mode_to_string(CpuMode mode) {
    switch (mode) {
    case CpuMode::User:
        return "USR";
    case CpuMode::FIQ:
        return "FIQ";
    case CpuMode::IRQ:
        return "IRQ";
    case CpuMode::Supervisor:
        return "SVC";
    case CpuMode::Abort:
        return "ABT";
    case CpuMode::Undefined:
        return "UND";
    case CpuMode::System:
        return "SYS";
    default:
        return "UNK";
    }
}

static const char* exec_mode_to_string(uint32_t cpsr) {
    bool thumb = (cpsr >> 5) & 1;
    return thumb ? "THUMB" : "ARM";
}
