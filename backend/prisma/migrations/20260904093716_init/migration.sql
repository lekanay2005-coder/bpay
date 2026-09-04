-- CreateTable
CREATE TABLE "AppUser" (
    "id" TEXT NOT NULL,
    "bmoniUserId" TEXT NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "ownerAddress" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AppUser_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SmartWallet" (
    "id" TEXT NOT NULL,
    "appUserId" TEXT NOT NULL,
    "bmoniWalletId" TEXT NOT NULL,
    "currency" TEXT NOT NULL,
    "address" TEXT,
    "status" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SmartWallet_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WebhookEvent" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "appUserId" TEXT,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processedAt" TIMESTAMP(3),

    CONSTRAINT "WebhookEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AppUser_bmoniUserId_key" ON "AppUser"("bmoniUserId");

-- CreateIndex
CREATE UNIQUE INDEX "AppUser_phoneNumber_key" ON "AppUser"("phoneNumber");

-- CreateIndex
CREATE UNIQUE INDEX "SmartWallet_bmoniWalletId_key" ON "SmartWallet"("bmoniWalletId");

-- CreateIndex
CREATE UNIQUE INDEX "SmartWallet_appUserId_currency_key" ON "SmartWallet"("appUserId", "currency");

-- AddForeignKey
ALTER TABLE "SmartWallet" ADD CONSTRAINT "SmartWallet_appUserId_fkey" FOREIGN KEY ("appUserId") REFERENCES "AppUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WebhookEvent" ADD CONSTRAINT "WebhookEvent_appUserId_fkey" FOREIGN KEY ("appUserId") REFERENCES "AppUser"("id") ON DELETE SET NULL ON UPDATE CASCADE;
