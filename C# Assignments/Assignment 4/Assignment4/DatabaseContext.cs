using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Assignment4;

public class DatabaseContext : DbContext
{
    public DbSet<Category> Categories { get; set; }
    public DbSet<Product> Products { get; set; }
    public DbSet<Order> Orders { get; set; }
    public DbSet<OrderDetails> OrderDetails { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.EnableSensitiveDataLogging();
        optionsBuilder.UseNpgsql("host=localhost;db=northwind;uid=postgres;password=;");
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Context for Category
        modelBuilder.Entity<Category>().ToTable("categories");
        modelBuilder.Entity<Category>().Property(x => x.Id).HasColumnName("categoryid");
        modelBuilder.Entity<Category>().Property(x => x.Name).HasColumnName("categoryname");
        modelBuilder.Entity<Category>().Property(x => x.Description).HasColumnName("description");

        // Context For Product
        modelBuilder.Entity<Product>().ToTable("products");
        modelBuilder.Entity<Product>().Property(x => x.Id).HasColumnName("productid");
        modelBuilder.Entity<Product>().Property(x => x.Name).HasColumnName("productname");
        modelBuilder.Entity<Product>().Property(x => x.UnitPrice).HasColumnName("unitprice");
        modelBuilder.Entity<Product>().Property(x => x.QuantityPerUnit).HasColumnName("quantityperunit");
        modelBuilder.Entity<Product>().Property(x => x.UnitsInStock).HasColumnName("unitsinstock");
        modelBuilder.Entity<Product>().Property(x => x.CategoryId).HasColumnName("categoryid");
        modelBuilder.Entity<Product>().Ignore(x => x.CategoryName);
        modelBuilder.Entity<Product>().Ignore(x => x.ProductName);

        // Context For Order
        modelBuilder.Entity<Order>().ToTable("orders");
        modelBuilder.Entity<Order>().Property(x => x.Id).HasColumnName("orderid");
        modelBuilder.Entity<Order>().Property(x => x.Date).HasColumnName("orderdate");
        modelBuilder.Entity<Order>().Property(x => x.Required).HasColumnName("requireddate");
        modelBuilder.Entity<Order>().Property(x => x.Shipped).HasColumnName("shippeddate");
        modelBuilder.Entity<Order>().Property(x => x.Freight).HasColumnName("freight");
        modelBuilder.Entity<Order>().Property(x => x.ShipName).HasColumnName("shipname");
        modelBuilder.Entity<Order>().Property(x => x.ShipCity).HasColumnName("shipcity");

        // Context for Order Details
        modelBuilder.Entity<OrderDetails>().ToTable("orderdetails")
            .HasKey(od => new { od.OrderId, od.ProductId });
        modelBuilder.Entity<OrderDetails>().Property(x => x.OrderId).HasColumnName("orderid");
        modelBuilder.Entity<OrderDetails>().Property(x => x.UnitPrice).HasColumnName("unitprice");
        modelBuilder.Entity<OrderDetails>().Property(x => x.Quantity).HasColumnName("quantity");
        modelBuilder.Entity<OrderDetails>().Property(x => x.Discount).HasColumnName("discount");
        modelBuilder.Entity<OrderDetails>().Property(x => x.ProductId).HasColumnName("productid");

        // Configuring relations
        modelBuilder.Entity<OrderDetails>()
            .HasOne(od => od.Order)
            .WithMany(o => o.OrderDetails)
            .HasForeignKey(od => od.OrderId);

        modelBuilder.Entity<OrderDetails>()
            .HasOne(od => od.Product)
            .WithMany()
            .HasForeignKey(od => od.ProductId);

        modelBuilder.Entity<Product>()
            .HasOne(p => p.Category)
            .WithMany()
            .HasForeignKey(p => p.CategoryId);
    }
}