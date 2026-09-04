-- CreateTable
CREATE TABLE "SplitBill" (
    "id" TEXT NOT NULL,
    "creatorAppUserId" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "currency" TEXT NOT NULL,
    "totalAmount" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SplitBill_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SplitBillContributor" (
    "id" TEXT NOT NULL,
    "splitBillId" TEXT NOT NULL,
    "appUserId" TEXT NOT NULL,
    "shareAmount" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "bmoniProposalId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SplitBillContributor_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ClaimableLink" (
    "id" TEXT NOT NULL,
    "senderAppUserId" TEXT NOT NULL,
    "amount" TEXT NOT NULL,
    "currency" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING_ESCROW',
    "escrowProposalId" TEXT,
    "releaseProposalId" TEXT,
    "claimedByAppUserId" TEXT,
    "claimedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ClaimableLink_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SplitBillContributor_splitBillId_appUserId_key" ON "SplitBillContributor"("splitBillId", "appUserId");

-- AddForeignKey
ALTER TABLE "SplitBill" ADD CONSTRAINT "SplitBill_creatorAppUserId_fkey" FOREIGN KEY ("creatorAppUserId") REFERENCES "AppUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SplitBillContributor" ADD CONSTRAINT "SplitBillContributor_splitBillId_fkey" FOREIGN KEY ("splitBillId") REFERENCES "SplitBill"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SplitBillContributor" ADD CONSTRAINT "SplitBillContributor_appUserId_fkey" FOREIGN KEY ("appUserId") REFERENCES "AppUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClaimableLink" ADD CONSTRAINT "ClaimableLink_senderAppUserId_fkey" FOREIGN KEY ("senderAppUserId") REFERENCES "AppUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClaimableLink" ADD CONSTRAINT "ClaimableLink_claimedByAppUserId_fkey" FOREIGN KEY ("claimedByAppUserId") REFERENCES "AppUser"("id") ON DELETE SET NULL ON UPDATE CASCADE;
