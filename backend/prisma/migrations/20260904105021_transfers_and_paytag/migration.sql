-- CreateTable
CREATE TABLE "PayTag" (
    "id" TEXT NOT NULL,
    "tag" TEXT NOT NULL,
    "appUserId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PayTag_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TransferProposal" (
    "id" TEXT NOT NULL,
    "appUserId" TEXT NOT NULL,
    "bmoniProposalId" TEXT NOT NULL,
    "smartWalletId" TEXT NOT NULL,
    "toBmoniUserId" TEXT,
    "toAddress" TEXT,
    "amount" TEXT NOT NULL,
    "currency" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "nextAction" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TransferProposal_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PayTag_tag_key" ON "PayTag"("tag");

-- CreateIndex
CREATE UNIQUE INDEX "PayTag_appUserId_key" ON "PayTag"("appUserId");

-- CreateIndex
CREATE UNIQUE INDEX "TransferProposal_bmoniProposalId_key" ON "TransferProposal"("bmoniProposalId");

-- AddForeignKey
ALTER TABLE "PayTag" ADD CONSTRAINT "PayTag_appUserId_fkey" FOREIGN KEY ("appUserId") REFERENCES "AppUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TransferProposal" ADD CONSTRAINT "TransferProposal_appUserId_fkey" FOREIGN KEY ("appUserId") REFERENCES "AppUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
